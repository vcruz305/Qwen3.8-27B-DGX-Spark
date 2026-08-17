#!/usr/bin/env bash
# Spark-survivable SGLang FP8 cell (same pins as NVFP4: official 0.95 SIGKILL'd).
set -euo pipefail
ROOT=/home/victor/qwen38-speed/sglang
VENV=/home/victor/work/sglang-venv
export PATH="$VENV/bin:/usr/local/cuda/bin:$PATH"
export SGLANG_BIN="$VENV/bin/sglang"
export CPATH=/home/victor/opt/python3.12-dev/usr/include/python3.12:/home/victor/opt/python3.12-dev/usr/include
export C_INCLUDE_PATH="$CPATH"
export MAX_JOBS=1
export CMAKE_BUILD_PARALLEL_LEVEL=1
export NINJAFLAGS="-j1"

cd "$ROOT"
./sglang-stop.sh || true
pkill -f 'sglang serve' || true
sleep 2

QUANT=fp8 MEM=0.80 \
  EXTRA_ARGS='--disable-flashinfer-autotune --cuda-graph-max-bs 8 --mamba-full-memory-ratio 4.59' \
  ./sglang-start.sh
echo START_FP8_OK
