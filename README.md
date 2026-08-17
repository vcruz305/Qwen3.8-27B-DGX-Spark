# Qwen3.8-27B on one DGX Spark (GB10)

[![License: MIT](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

Copy-paste serve for **Qwen3.8-27B GGUF** with **llama.cpp** on a single **NVIDIA DGX Spark (GB10 / SM121, ~128 GB unified)**.

This is **not** the [Turing 24 GB recipe](https://github.com/vcruz305/Qwen3.8-27B-Turing-RTX-6000), **not** the [Ada 48 GB recipe](https://github.com/vcruz305/Qwen3.8-27B-Ada-RTX-6000), and **not** the Bakeer vLLM + NVFP4 + DSpark pack. One Spark. GGUF. llama.cpp.

- Stock pack: [vcruz305/Qwen3.8-27B-GGUF](https://huggingface.co/vcruz305/Qwen3.8-27B-GGUF)
- AEON Ultimate bake (MTP in-file): [vcruz305/Qwen3.8-27B-AEON-ULTIMATE-UNCENSORED-GGUF](https://huggingface.co/vcruz305/Qwen3.8-27B-AEON-ULTIMATE-UNCENSORED-GGUF)
- Measured **pp512 / tg128** on two Sparks, 2026-08-16
- Default pick: **stock Q4_K_M** (fastest GGUF decode here)

## What tg128 and pp512 mean

`llama-bench` reports two different jobs. People mix them up.

| Label | What it measures | Everyday name |
|---|---|---|
| **tg128** | Generate 128 new tokens after the prompt is already in KV | **Decode tok/s** — this is the “tok/s” people quote |
| **pp512** | Ingest a 512-token prompt (no generation) | **Prefill tok/s** — prompt processing |

**Quote tg128** when someone asks “how fast is it?” That is tokens out of the model while chatting.

**pp512** is how fast the prompt is eaten. It is usually hundreds of tok/s. It is not chat speed.

Bakeer “75 tok/s” is neither of these. It is vLLM + Unsloth NVFP4 + DSpark `k=14` on an **edit-heavy** 3k-token rewrite. Fresh gen on that stack is ~29 tok/s. Different weights, different engine.

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

Q8 was not benched. llama-cli `draft-mtp` / ngram did not yield a clean timed run on this pass.

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

## What this repo is not

- **Turing RTX 6000 24 GB** — use [Qwen3.8-27B-Turing-RTX-6000](https://github.com/vcruz305/Qwen3.8-27B-Turing-RTX-6000)
- **Ada RTX 6000 48 GB** — use [Qwen3.8-27B-Ada-RTX-6000](https://github.com/vcruz305/Qwen3.8-27B-Ada-RTX-6000)
- **vLLM + Unsloth NVFP4 + DSpark** — that is the Bakeer 75 tok/s path, not these GGUFs
- **Multi-Spark TP** — one box only

## Credits

- [Qwen/Qwen3.8-27B](https://huggingface.co/Qwen/Qwen3.8-27B) — base
- [AEON-7](https://huggingface.co/AEON-7) — abliterated BF16
- [vcruz305](https://huggingface.co/vcruz305) — GGUF packs
- [llama.cpp](https://github.com/ggml-org/llama.cpp)
