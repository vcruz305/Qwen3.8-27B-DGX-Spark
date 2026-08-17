# Qwen3.8-27B on one DGX Spark (GB10)

[![License: MIT](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

Copy-paste serve for **Qwen3.8-27B GGUF** with **llama.cpp** on a single **NVIDIA DGX Spark (GB10 / SM121, ~128 GB unified)**.

- Stock pack: [vcruz305/Qwen3.8-27B-GGUF](https://huggingface.co/vcruz305/Qwen3.8-27B-GGUF)
- AEON Ultimate bake (MTP in-file): [vcruz305/Qwen3.8-27B-AEON-ULTIMATE-UNCENSORED-GGUF](https://huggingface.co/vcruz305/Qwen3.8-27B-AEON-ULTIMATE-UNCENSORED-GGUF)
- Measured **pp512 / tg128** (llama.cpp) and **vLLM NVFP4 + DSpark** on Spark, 2026-08-16
- Default GGUF pick: **stock Q4_K_M** (fastest GGUF decode here)

## What tg128 and pp512 mean

`llama-bench` reports two different jobs. People mix them up.

| Label | What it measures | Everyday name |
|---|---|---|
| **tg128** | Generate 128 new tokens after the prompt is already in KV | **Decode tok/s** — this is the “tok/s” people quote |
| **pp512** | Ingest a 512-token prompt (no generation) | **Prefill tok/s** — prompt processing |

**Quote tg128** when someone asks “how fast is the GGUF?” That is tokens out of llama.cpp while chatting.

**pp512** is how fast the prompt is eaten. It is usually hundreds of tok/s. It is not chat speed.

vLLM numbers below are a different engine (NVFP4 + DSpark). Do not average them with tg128.

## Requirements

| Component | Detail |
|---|---|
| Hardware | 1× DGX Spark, NVIDIA GB10, SM 121 |
| Runtime | llama.cpp built with CUDA (`-DGGML_CUDA=ON`) |
| CLI | `hf` or `huggingface-cli`, `curl` |
| This fleet | `LLAMA_DIR=/home/victor/nemotron-quant/llama.cpp/build/bin` (b610) |

## Quick start

```bash
./download.sh                 # stock Q4_K_M into ./models
./bench.sh                    # reprint pp512 / tg128
# if you have llama-server in LLAMA_DIR:
./start.sh
curl http://127.0.0.1:8085/v1/models
./stop.sh
```

AEON bake:

```bash
PACK=aeon QUANT=Q4_K_M ./download.sh
PACK=aeon QUANT=Q4_K_M ./bench.sh
PACK=aeon QUANT=Q4_K_M SPEC=mtp K=2 ./start.sh
```

## Measured (2026-08-16)

Same command on both boxes:

```
llama-bench -m <gguf> -ngl 99 -fa on -p 512 -n 128 -r 3 -o md
```

Binary: `/home/victor/nemotron-quant/llama.cpp/build/bin/llama-bench` build `70dfba5 (1)`. CUDA, flash-attn on, full offload. **No speculative decoding.**

### Stock — Spark b610

`vcruz305/Qwen3.8-27B-GGUF` · 26.90B

| Quant | Size | Prefill pp512 | Decode tg128 |
|---|---:|---:|---:|
| **Q4_K_M** | 15.40 GiB | 844.11 ± 8.48 | **12.38 ± 0.03** |
| Q5_K_M | 17.90 GiB | 813.97 ± 12.58 | 10.82 ± 0.01 |
| Q6_K | 20.56 GiB | 706.57 ± 9.40 | 9.42 ± 0.01 |

### AEON Ultimate bake — Spark 9f73

`vcruz305/Qwen3.8-27B-AEON-ULTIMATE-UNCENSORED-GGUF` · 27.32B (nextn baked in)

| Quant | Size | Prefill pp512 | Decode tg128 |
|---|---:|---:|---:|
| Q4_K_M | 15.65 GiB | 835.33 ± 16.70 | **12.19 ± 0.02** |
| Q5_K_M | 18.18 GiB | 805.39 ± 12.30 | 10.65 ± 0.02 |
| Q6_K | 20.88 GiB | 700.47 ± 5.27 | 9.18 ± 0.00 |

**Default pick: stock Q4_K_M, 12.38 decode tok/s.** AEON is ~1.5% slower at the same quant (extra MTP tensors). Files were left on the Sparks under `/home/victor/qwen38-speed/`.

## sixcat-eval (this run)

Harness: [vcruz305/sixcat-eval](https://github.com/vcruz305/sixcat-eval). `--limit 20` (~180 items), `--max-minutes 30`, thinking off, `-c 262144 -ctk q4_0 -ctv q4_0`. Neither run timed out.

- **b610 stock Q4** `qwen38-27b` spec off
- **9f73 AEON bake Q4** `qwen38-aeon` `--spec-type draft-mtp --spec-draft-n-max 2`

| | Stock Q4 | AEON bake Q4 + MTP | Δ |
|---|---:|---:|---:|
| **overall** | **82.3** | **80.0** | −2.3 |
| knowledge | 88.8 | 90.0 | +1.2 |
| math | 40.0 | 25.0 | −15.0 |
| truth | 85.0 | 85.0 | 0 |
| instruct | 80.0 | 80.0 | 0 |
| code | 100 | 100 | 0 |
| tools | 100 | 100 | 0 |

Receipts: [`logs/sixcat-stock-q4km.json`](logs/sixcat-stock-q4km.json), [`logs/sixcat-aeon-q4km.json`](logs/sixcat-aeon-q4km.json).

```bash
python -m sixcat --base-url http://127.0.0.1:8085/v1 --model qwen38-27b --limit 20 --max-minutes 30 --out run.json
```

## vLLM NVFP4 + DSpark (this run)

Single Spark 9f73. Host vLLM (no Docker). One stream. `completion_tokens / wall`. Thinking off.

- Target: [unsloth/Qwen3.8-27B-NVFP4](https://huggingface.co/unsloth/Qwen3.8-27B-NVFP4)
- Drafter: [Doopeworld/Qwen3.8-27B-DSpark-vLLM](https://huggingface.co/Doopeworld/Qwen3.8-27B-DSpark-vLLM)
- Receipt: [`logs/vllm-nvfp4-dspark-20260816.md`](logs/vllm-nvfp4-dspark-20260816.md)

**Fresh** is a short “write this module” prompt. **Rewrite** already has the source in the prompt and asks to add a method to every class, then dump the file. Rewrite is high draft-accept. A new-question harness tracks the fresh column.

### k=7

| Workload | out tok | wall s | tok/s |
|---|---:|---:|---:|
| Fresh (cap 400) | 146 | 3.62 | **40.33** |
| Rewrite (cap 1500) | 1140 | 18.06 | 63.12 |
| Rewrite (cap 3000) | 2300 | 35.68 | **64.45** |

Draft accept after those three: **98.8%** (3134 / 3171).

### k=14

| Workload | out tok | wall s | tok/s |
|---|---:|---:|---:|
| Fresh (cap 400) | 146 | 3.82 | **38.19** |
| Rewrite (cap 1500) | 1145 | 15.28 | **74.93** |
| Rewrite (cap 3000) | 2300 | 30.85 | **74.56** |

k=14 is slower on fresh and faster on rewrite. Quote **38.19** for a new-question harness.

```bash
VLLM_MARLIN_USE_ATOMIC_ADD=1 \
vllm serve /path/to/nvfp4 \
  --served-model-name qwen3.8-27b \
  --host 127.0.0.1 --port 8002 \
  --max-model-len 262144 \
  --gpu-memory-utilization 0.85 \
  --max-num-batched-tokens 16384 \
  --enable-prefix-caching \
  --speculative-config '{"method":"dspark","model":"/path/to/dspark","num_speculative_tokens":7,"draft_sample_method":"probabilistic"}'
```

Q8 GGUF was not benched. llama-cli `draft-mtp` / ngram did not yield a clean timed run on this pass.

Same GGUF family on other cards (different repos, do not average):

| Card | Stock Q4_K_M tg128 |
|---|---:|
| Turing RTX 6000 24 GB | 24.36 |
| Ada RTX 6000 48 GB | 46.0 |
| **DGX Spark GB10 (this repo)** | **12.38** |

## Scripts

| Script | What it does |
|---|---|
| `download.sh` | One GGUF. `PACK=stock` or `PACK=aeon`. `QUANT=Q4_K_M` default |
| `bench.sh` | `llama-bench` pp512 / tg128 |
| `start.sh` | `llama-server` if present. `SPEC=mtp` for AEON `draft-mtp` |
| `stop.sh` | Kills `.llama.pid` |

## Serve flags

```bash
llama-server \
  -m models/Qwen3.8-27B-Q4_K_M.gguf \
  -a qwen38-27b \
  --host 127.0.0.1 --port 8085 \
  -ngl 99 -fa on -b 512 -ub 512 -c 32768 -np 1 \
  --jinja --reasoning-format deepseek
```

AEON native MTP (needs a llama.cpp that understands `draft-mtp`):

```bash
llama-server \
  -m models/Qwen3.8-27B-AEON-ULTIMATE-UNCENSORED-Q4_K_M.gguf \
  --spec-type draft-mtp --spec-draft-n-max 2 --spec-draft-p-min 0.7 \
  --parallel 1 --jinja --reasoning-format deepseek \
  -ngl 99 -fa on -b 512 -ub 512 -c 32768
```

## Credits

- [Qwen/Qwen3.8-27B](https://huggingface.co/Qwen/Qwen3.8-27B) — base
- [AEON-7](https://huggingface.co/AEON-7) — abliterated BF16
- [vcruz305](https://huggingface.co/vcruz305) — GGUF packs
- [unsloth/Qwen3.8-27B-NVFP4](https://huggingface.co/unsloth/Qwen3.8-27B-NVFP4) — 4-bit target
- [Doopeworld/Qwen3.8-27B-DSpark-vLLM](https://huggingface.co/Doopeworld/Qwen3.8-27B-DSpark-vLLM) — drafter
- [sixcat-eval](https://github.com/vcruz305/sixcat-eval) — quality battery
- [llama.cpp](https://github.com/ggml-org/llama.cpp)
- [vLLM](https://github.com/vllm-project/vllm)
