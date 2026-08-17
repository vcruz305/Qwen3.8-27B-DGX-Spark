# vLLM NVFP4 + DSpark — 2026-08-16 Spark 9f73 (GB10)

Host vLLM `0.1.dev1+g75231eff2.d20260809`. No Docker. One stream.
`completion_tokens / wall`. Thinking off.

Weights:
- target: `unsloth/Qwen3.8-27B-NVFP4` (22.57 GB + 0.85 GB MTP sidecar)
- drafter: `Doopeworld/Qwen3.8-27B-DSpark-vLLM` (2.72 GB)

Launch from this repo: `./vllm-start.sh` then `python3 ./vllm-smoke.py --warmup-only`.

Kernel path this build picked: FlashInferCutlassNvFp4LinearKernel, FLASHINFER attn.
KV cache 1,357,257 tokens at depth 7; 1,204,453 tokens at depth 14.

## Workloads used for the numbers below

**New write** — short program prompt, nothing in context to copy.

**Repeat file** — a long file already in the prompt; change one field and reprint.

A new-question harness tracks the new-write column.

## Depth 7

| Workload | prompt tok | out tok | wall s | tok/s | finish |
|---|---:|---:|---:|---:|---|
| New write (cap 400, first req) | 32 | 146 | 3.62 | **40.33** | stop |
| Repeat file (cap 1500) | 738 | 1140 | 18.06 | **63.12** | stop |
| Repeat file (cap 3000) | 1458 | 2300 | 35.68 | **64.45** | stop |

Spec counters after those three: 3134 / 3171 draft tokens accepted (**98.8%**).

## Depth 14

| Workload | prompt tok | out tok | wall s | tok/s | finish |
|---|---:|---:|---:|---:|---|
| New write (cap 400, first req) | 32 | 146 | 3.82 | **38.19** | stop |
| Repeat file (cap 1500) | 738 | 1145 | 15.28 | **74.93** | stop |
| Repeat file (cap 3000) | 1458 | 2300 | 30.85 | **74.56** | stop |

After a 32-token warmup on the same process:

| Workload | prompt tok | out tok | wall s | tok/s | finish |
|---|---:|---:|---:|---:|---|
| New write (cap 400, warm) | 32 | 146 | 2.91 | **50.13** | stop |
| Repeat file (cap 3000, warm) | 1458 | 2300 | 30.78 | 74.72 | stop |
| Repeat file (cap 3000, cached) | 1458 | 2300 | 30.43 | **75.58** | stop |

Quote **50.13** for a new-question harness after one warmup ping. Quote **38.19** only as first request. Repeat-file sits at ~75.

## Squeeze attempts (same box, warmup ping)

None beat wide depth 14 + warmup.

| Config | New write warm | Repeat warm | Repeat cached |
|---|---:|---:|---:|
| **DSpark depth 14, 256k, default seqs (keep)** | **50.13** | 74.72 | **75.58** |
| DSpark depth 14, 32k, `--max-num-seqs 1` | 47.36 | 75.03 | 74.90 |
| DSpark depth 7, 256k, warm | 39.14 | 64.04 | 62.86 |
| In-file MTP n=3, 256k | 29.61 | 32.34 | 32.29 |

`--max-num-seqs 1` shrank CUDA graphs (capture max 24) and lost ~3 tok/s on new write.
Depth 7 stays worse on both columns once warm. MTP does not replace DSpark here.

Default: **DSpark depth 14, 256k, warmup ping, no max-num-seqs pin.**
