# vLLM NVFP4 + DSpark — 2026-08-16 Spark 9f73 (GB10)

Host vLLM `0.1.dev1+g75231eff2.d20260809` in `/home/victor/work/k3-vllm-venv`.
No Docker. One stream. `completion_tokens / wall` (prefill inside the wall).
Thinking off.

Weights:
- target: `unsloth/Qwen3.8-27B-NVFP4` (22.57 GB + 0.85 GB MTP sidecar)
- drafter: `Doopeworld/Qwen3.8-27B-DSpark-vLLM` (2.72 GB)

Serve:
```
VLLM_MARLIN_USE_ATOMIC_ADD=1
vllm serve /path/to/nvfp4 \
  --served-model-name qwen3.8-27b \
  --host 127.0.0.1 --port 8002 \
  --max-model-len 262144 \
  --gpu-memory-utilization 0.85 \
  --max-num-batched-tokens 16384 \
  --enable-prefix-caching \
  --speculative-config '{"method":"dspark","model":"/path/to/dspark","num_speculative_tokens":K,"draft_sample_method":"probabilistic"}'
```

Kernel path this build picked: FlashInferCutlassNvFp4LinearKernel, FLASHINFER attn, KV cache 1,357,257 tokens at k=7.

## Workloads

**Fresh** — short “write this module” prompt. Nothing in context to copy. Low draft accept.

**Rewrite** — source file already in the prompt; ask to add a method to every class and dump the whole file. High draft accept (~99%).

These are single-stream. A new-question harness (sixcat, chat) tracks the fresh column. Concurrent streams share the GPU; per-stream drops.

## k=7 (measured)

| Workload | prompt tok | out tok | wall s | tok/s | finish |
|---|---:|---:|---:|---:|---|
| Fresh (cap 400) | 32 | 146 | 3.62 | **40.33** | stop |
| Rewrite (cap 1500) | 738 | 1140 | 18.06 | **63.12** | stop |
| Rewrite (cap 3000) | 1458 | 2300 | 35.68 | **64.45** | stop |

Spec counters after those three: 3134 / 3171 draft tokens accepted (**98.8%**).

## k=14 (measured)

Same box, same weights, `num_speculative_tokens=14`. KV cache 1,204,453 tokens.

| Workload | prompt tok | out tok | wall s | tok/s | finish |
|---|---:|---:|---:|---:|---|
| Fresh (cap 400) | 32 | 146 | 3.82 | **38.19** | stop |
| Rewrite (cap 1500) | 738 | 1145 | 15.28 | **74.93** | stop |
| Rewrite (cap 3000) | 1458 | 2300 | 30.85 | **74.56** | stop |

k=14 is slower on fresh (more wasted drafts) and faster on rewrite. Quote **38.19** for a new-question harness. Quote **74.56–74.93** only for rewrite-with-source-in-prompt.

Spec counters after those three: 3228 / 5096 draft tokens accepted (**63.3%**). Mean ~9.87 accepted tok/draft (3228 / 364).
