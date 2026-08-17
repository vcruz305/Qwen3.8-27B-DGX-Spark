# llama-bench 2026-08-16 DGX Spark GB10

Command:

```
llama-bench -m <gguf> -ngl 99 -fa on -p 512 -n 128 -r 3 -o md
```

Binary: `/home/victor/nemotron-quant/llama.cpp/build/bin/llama-bench` build `70dfba5 (1)`
(9f73 used a copy of the same bins under `/home/victor/qwen38-speed/bin`).

## b610 stock

```
| model                          |       size |     params | backend    | ngl |  fa |            test |                  t/s |
| qwen35 27B Q4_K - Medium       |  15.40 GiB |    26.90 B | CUDA       |  99 |   1 |           pp512 |        844.11 ± 8.48 |
| qwen35 27B Q4_K - Medium       |  15.40 GiB |    26.90 B | CUDA       |  99 |   1 |           tg128 |         12.38 ± 0.03 |
| qwen35 27B Q5_K - Medium       |  17.90 GiB |    26.90 B | CUDA       |  99 |   1 |           pp512 |       813.97 ± 12.58 |
| qwen35 27B Q5_K - Medium       |  17.90 GiB |    26.90 B | CUDA       |  99 |   1 |           tg128 |         10.82 ± 0.01 |
| qwen35 27B Q6_K                |  20.56 GiB |    26.90 B | CUDA       |  99 |   1 |           pp512 |        706.57 ± 9.40 |
| qwen35 27B Q6_K                |  20.56 GiB |    26.90 B | CUDA       |  99 |   1 |           tg128 |          9.42 ± 0.01 |
```

## 9f73 AEON Ultimate bake

```
| model                          |       size |     params | backend    | ngl |  fa |            test |                  t/s |
| qwen35 27B Q4_K - Medium       |  15.65 GiB |    27.32 B | CUDA       |  99 |   1 |           pp512 |       835.33 ± 16.70 |
| qwen35 27B Q4_K - Medium       |  15.65 GiB |    27.32 B | CUDA       |  99 |   1 |           tg128 |         12.19 ± 0.02 |
| qwen35 27B Q5_K - Medium       |  18.18 GiB |    27.32 B | CUDA       |  99 |   1 |           pp512 |       805.39 ± 12.30 |
| qwen35 27B Q5_K - Medium       |  18.18 GiB |    27.32 B | CUDA       |  99 |   1 |           tg128 |         10.65 ± 0.02 |
| qwen35 27B Q6_K                |  20.88 GiB |    27.32 B | CUDA       |  99 |   1 |           pp512 |        700.47 ± 5.27 |
| qwen35 27B Q6_K                |  20.88 GiB |    27.32 B | CUDA       |  99 |   1 |           tg128 |          9.18 ± 0.00 |
```
