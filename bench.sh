#!/usr/bin/env bash
# llama-bench pp512 / tg128 on one DGX Spark GB10.
set -euo pipefail
cd "$(dirname "$0")"

PACK="${PACK:-stock}"
QUANT="${QUANT:-Q4_K_M}"
if [[ "$PACK" == "aeon" ]]; then
  DEFAULT_MODEL="$PWD/models/Qwen3.8-27B-AEON-ULTIMATE-UNCENSORED-${QUANT}.gguf"
else
  DEFAULT_MODEL="$PWD/models/Qwen3.8-27B-${QUANT}.gguf"
fi
MODEL="${MODEL:-$DEFAULT_MODEL}"
GPU="${CUDA_VISIBLE_DEVICES:-0}"
LOG="logs/llama-bench-$(date +%Y%m%d_%H%M%S).log"
mkdir -p logs

if [[ -z "${LLAMA_DIR:-}" ]]; then
  if [[ -x /home/victor/nemotron-quant/llama.cpp/build/bin/llama-bench ]]; then
    LLAMA_DIR=/home/victor/nemotron-quant/llama.cpp/build/bin
  elif [[ -x /home/victor/qwen38-speed/bin/llama-bench ]]; then
    LLAMA_DIR=/home/victor/qwen38-speed/bin
  else
    LLAMA_DIR=/home/victor/nemotron-quant/llama.cpp/build/bin
  fi
fi

BENCH="$LLAMA_DIR/llama-bench"
if [[ ! -x "$BENCH" ]]; then
  echo "llama-bench not at $BENCH — set LLAMA_DIR" >&2
  exit 1
fi
if [[ ! -f "$MODEL" ]]; then
  echo "missing $MODEL — run PACK=$PACK QUANT=$QUANT ./download.sh" >&2
  exit 1
fi

export CUDA_VISIBLE_DEVICES="$GPU"
export LD_LIBRARY_PATH="${LLAMA_DIR}:/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"

echo "bench $MODEL  GPU=$GPU" | tee "$LOG"
"$BENCH" -m "$MODEL" -ngl 99 -fa on -p 512 -n 128 -r 3 -o md | tee -a "$LOG"
echo "wrote $LOG"
