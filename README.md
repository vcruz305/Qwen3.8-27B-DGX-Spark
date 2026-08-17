# Qwen3.8-27B on one DGX Spark (GB10)

[![License: MIT](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

Measured serve for **Qwen3.8-27B** on a single **NVIDIA DGX Spark (GB10 / SM121, ~128 GB unified)**. 2026-08-16.

**Default: vLLM + NVFP4 + DSpark depth 14, 256k context, one warmup ping.** New write **50.13 tok/s**. Repeat file **75.58 tok/s**.

## Scoreboard (fastest first)

One stream. Spark 9f73 unless noted. vLLM rows are `completion_tokens / wall`, thinking off, after a 32-token warmup unless marked cold. GGUF rows are `llama-bench` tg128 (no spec).

| Rank | Config | New write / decode | Repeat file | Notes |
|---:|---|---:|---:|---|
| 1 | **vLLM NVFP4 + DSpark depth 14, 256k (warm)** | **50.13** | **75.58** cached | keep this |
| 2 | vLLM NVFP4 + DSpark depth 14, 32k, `--max-num-seqs 1` | 47.36 | 75.03 | tighter graphs, slower |
| 3 | vLLM NVFP4 + DSpark depth 7, 256k (cold) | 40.33 | 64.45 | first-request depth 7 |
| 4 | vLLM NVFP4 + DSpark depth 7, 256k (warm) | 39.14 | 64.04 | worse than 14 once warm |
| 5 | vLLM NVFP4 + DSpark depth 14, 256k (cold) | 38.19 | 74.56 | first request pays JIT |
| 6 | vLLM NVFP4 + in-file MTP n=3 | 29.61 | 32.34 | do not use |
| 7 | llama.cpp stock Q4_K_M (b610) | **12.38** tg128 | — | fastest GGUF |
| 8 | llama.cpp AEON Q4_K_M + baked MTP (9f73) | 12.19 tg128 | — | sixcat run used this |
| 9 | llama.cpp stock Q5_K_M | 10.82 tg128 | — | |
| 10 | llama.cpp stock Q6_K | 9.42 tg128 | — | |

Do not average vLLM wall-clock tok/s with llama.cpp tg128.

**New write** = short “write this program” prompt (harness / chat). **Repeat file** = a long file already in the prompt; change one field everywhere and reprint it (high draft-accept).

## Fastest serve

```bash
# weights already on disk as models/nvfp4 and models/dspark
./vllm-start.sh
python3 ./vllm-smoke.py --warmup-only
python3 ./vllm-smoke.py --label warm
./vllm-stop.sh
```

`DEPTH=14` is the default. Host vLLM only.

- Target: [unsloth/Qwen3.8-27B-NVFP4](https://huggingface.co/unsloth/Qwen3.8-27B-NVFP4)
- Drafter: [Doopeworld/Qwen3.8-27B-DSpark-vLLM](https://huggingface.co/Doopeworld/Qwen3.8-27B-DSpark-vLLM)
- Receipt: [`logs/vllm-nvfp4-dspark-20260816.md`](logs/vllm-nvfp4-dspark-20260816.md)
- Host vLLM `0.1.dev1+g75231eff2.d20260809` on 9f73. No Docker.

## vLLM detail

### 1. DSpark depth 14, 256k, warm (winner)

| Workload | out tok | wall s | tok/s |
|---|---:|---:|---:|
| New write (cap 400) | 146 | 2.91 | **50.13** |
| Repeat file (cap 3000) | 2300 | 30.78 | 74.72 |
| Repeat file (cap 3000, prefix cached) | 2300 | 30.43 | **75.58** |

Cold first request on this same process: new write **38.19**, repeat file **74.56**.

### 2. DSpark depth 14, 32k, `--max-num-seqs 1`

New write **47.36**. Repeat file **75.03**. CUDA graph capture max 24. Dropped.

### 3. DSpark depth 7, 256k

| Workload | tok/s |
|---|---:|
| New write cold | 40.33 |
| New write warm | 39.14 |
| Repeat file cap 3000 cold | 64.45 |
| Repeat file cap 3000 warm | 64.04 |

Draft accept on the cold depth-7 trio: **98.8%** (3134 / 3171).

### 4. In-file MTP n=3

New write **29.61**. Repeat file **32.34**. Lost.

## llama.cpp GGUF (slower decode)

Quote **tg128** as GGUF chat speed. **pp512** is prefill only.

```
llama-bench -m <gguf> -ngl 99 -fa on -p 512 -n 128 -r 3 -o md
```

Binary `70dfba5`, CUDA, flash-attn on, full offload, no speculative decoding. Receipt: [`logs/llama-bench-spark-20260816.md`](logs/llama-bench-spark-20260816.md).

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

Fastest GGUF: **stock Q4_K_M, 12.38 decode tok/s.**

```bash
./download.sh                 # stock Q4_K_M into ./models
./bench.sh
./start.sh
curl http://127.0.0.1:8085/v1/models
./stop.sh
```

```bash
llama-server \
  -m models/Qwen3.8-27B-Q4_K_M.gguf \
  -a qwen38-27b \
  --host 127.0.0.1 --port 8085 \
  -ngl 99 -fa on -b 512 -ub 512 -c 32768 -np 1 \
  --jinja --reasoning-format deepseek
```

AEON bake:

```bash
PACK=aeon QUANT=Q4_K_M ./download.sh
PACK=aeon QUANT=Q4_K_M SPEC=mtp K=2 ./start.sh
```

```bash
llama-server \
  -m models/Qwen3.8-27B-AEON-ULTIMATE-UNCENSORED-Q4_K_M.gguf \
  --spec-type draft-mtp --spec-draft-n-max 2 --spec-draft-p-min 0.7 \
  --parallel 1 --jinja --reasoning-format deepseek \
  -ngl 99 -fa on -b 512 -ub 512 -c 32768
```

Same GGUF family on other cards (different repos, do not average):

| Card | Stock Q4_K_M tg128 |
|---|---:|
| Turing RTX 6000 24 GB | 24.36 |
| Ada RTX 6000 48 GB | 46.0 |
| **DGX Spark GB10 (this repo)** | **12.38** |

Q8 GGUF was not benched. llama-cli `draft-mtp` / ngram did not yield a clean timed run on this pass.

## sixcat-eval (GGUF)

Harness: [vcruz305/sixcat-eval](https://github.com/vcruz305/sixcat-eval). `--limit 20` (~180 items), `--max-minutes 30`, thinking off, `-c 262144 -ctk q4_0 -ctv q4_0`. Neither run timed out.

| | Stock Q4 (b610) | AEON bake Q4 + MTP (9f73) | Δ |
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

## Scripts

| Script | What it does |
|---|---|
| `download.sh` | One GGUF. `PACK=stock` or `PACK=aeon`. `QUANT=Q4_K_M` default |
| `bench.sh` | `llama-bench` pp512 / tg128 |
| `start.sh` | `llama-server` if present. `SPEC=mtp` for AEON `draft-mtp` |
| `stop.sh` | Kills `.llama.pid` |
| `vllm-start.sh` | Host vLLM + DSpark. `DEPTH=14` default |
| `vllm-smoke.py` | Warmup + new-write + repeat-file timing |
| `vllm-stop.sh` | Kills `.vllm.pid` |

## Credits

- [Qwen/Qwen3.8-27B](https://huggingface.co/Qwen/Qwen3.8-27B) — base
- [AEON-7](https://huggingface.co/AEON-7) — abliterated BF16
- [vcruz305](https://huggingface.co/vcruz305) — GGUF packs
- [unsloth/Qwen3.8-27B-NVFP4](https://huggingface.co/unsloth/Qwen3.8-27B-NVFP4) — 4-bit target
- [Doopeworld/Qwen3.8-27B-DSpark-vLLM](https://huggingface.co/Doopeworld/Qwen3.8-27B-DSpark-vLLM) — drafter
- [sixcat-eval](https://github.com/vcruz305/sixcat-eval) — quality battery
- [llama.cpp](https://github.com/ggml-org/llama.cpp)
- [vLLM](https://github.com/vllm-project/vllm)
