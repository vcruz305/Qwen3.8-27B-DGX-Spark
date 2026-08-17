# SGLang NVFP4 — 2026-08-17 Spark b610 (GB10)

Host SGLang `0.5.17` + FlashInfer `0.6.15.post1` + torch `2.11.0+cu130`. No Docker. One stream.
`completion_tokens / wall`. Thinking off. Same `vllm-smoke.py` prompts as the vLLM rows.

Weights: `RadixArk/Qwen3.8-27B-NVFP4` on disk at `models/nvfp4-radix` (modelopt mixed / NVFP4).
Alias `qwen3.8-27b`. `max_model_len=262144`.

## Official cookbook cell dies

`hw=dgx-spark variant=default strategy=balanced nodes=single` uses `--mem-fraction-static 0.95` and no mamba pin.

Two SIGKILL (-9) boots on this box:

1. Official `0.95` + FlashInfer autotune. Unified-memory peak during autotune.
2. Official `0.95` + `--disable-flashinfer-autotune`. Weights 22.20 GB, Mamba SSM 39.66 GB, KV 22.60+22.60 GB, **7.99 GB left**. Died at CUDA-graph capture `bs=56` while JIT-compiling `fp4_gemm_cutlass_sm120`.

Ninja also SIGKILL'd when the model was already resident (parallel `nvcc` on 121 GB unified).

## Spark-survivable cell (this receipt)

```bash
# once, box empty: finish FlashInfer FP4 GEMM at -j1
# scripts/start-sglang-nvfp4.sh does this, then:
QUANT=nvfp4 MEM=0.80 EXTRA_ARGS='--disable-flashinfer-autotune --cuda-graph-max-bs 8 --mamba-full-memory-ratio 4.59' \
  ./sglang-start.sh
python3 ./vllm-smoke.py --base http://127.0.0.1:30000/v1 --warmup-only
python3 ./vllm-smoke.py --base http://127.0.0.1:30000/v1 --label sglang-nvfp4-0.80
```

Flags that actually came up:

- `--mem-fraction-static 0.80`
- `--attention-backend flashinfer`
- `--chunked-prefill-size 8192`
- `--disable-prefill-cuda-graph`
- `--disable-flashinfer-autotune`
- `--cuda-graph-max-bs 8`
- `--mamba-full-memory-ratio 4.59`
- `--reasoning-parser qwen3 --tool-call-parser qwen3_coder`

Pool after load: weights **22.54 GB**, Mamba conv 1.08 + SSM **55.12 GB**, KV FP8 6.13+6.13 GB, **21.76 GB** left. Graphs `bs=[1,2,4,8]` in **13.88 s**. `max_total_num_tokens=407175`, `max_running_requests=78`. Engine: `load_weight=144.28 s`, `scheduler_e2e=167.34 s`.

`MAX_JOBS=1` on the pre-link. Cached module: `/home/victor/.cache/flashinfer/0.6.15.post1/121a/cached_ops/fp4_gemm_cutlass_sm120/fp4_gemm_cutlass_sm120.so`.

## Smoke (warm, after 32-token ping)

| Workload | prompt tok | out tok | wall s | tok/s | finish |
|---|---:|---:|---:|---:|---|
| New write (cap 400) | 42 | 81 | 6.78 | **11.94** | stop |
| Repeat file (cap 3000) | 2438 | 2323 | 194.72 | 11.93 | stop |
| Repeat file (cap 3000, cached) | 2438 | 2328 | 194.54 | **11.97** | stop |

No speculative decoding. Do not average with vLLM+DSpark 50 / 75. This is in the GGUF-decode band.

## Honest notes

- Official `0.95` is not Spark-survivable on this hybrid GDN + NVFP4 first boot.
- Cookbook mamba ratio `4.59` is what we pinned; it spends most of the 0.80 pool on SSM, not KV.
- Pre-link the FP4 GEMM `.so` on an empty box. Do not let ninja compile it under a loaded model.
