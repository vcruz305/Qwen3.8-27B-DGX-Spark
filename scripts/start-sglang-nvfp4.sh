#!/usr/bin/env bash
# Finish the FlashInfer FP4 GEMM ninja that SIGKILL'd under a loaded model,
# then start the Spark-survivable NVFP4 cookbook cell.
set -euo pipefail
ROOT=/home/victor/qwen38-speed/sglang
VENV=/home/victor/work/sglang-venv
FI=/home/victor/.cache/flashinfer/0.6.15.post1/121a/cached_ops/fp4_gemm_cutlass_sm120
export PATH="$VENV/bin:/usr/local/cuda/bin:$PATH"
export SGLANG_BIN="$VENV/bin/sglang"
export CPATH=/home/victor/opt/python3.12-dev/usr/include/python3.12:/home/victor/opt/python3.12-dev/usr/include
export C_INCLUDE_PATH="$CPATH"
export MAX_JOBS=1
export CMAKE_BUILD_PARALLEL_LEVEL=1
export NINJAFLAGS="-j1"

echo "=== stop leftovers ==="
cd "$ROOT"
./sglang-stop.sh || true
pkill -f 'sglang serve' || true
sleep 2

echo "=== ninja fp4 gemm -j1 ==="
if [[ -d "$FI" && -f "$FI/build.ninja" ]]; then
  (cd "$FI" && ninja -j1) || {
    echo "ninja failed; listing:"
    ls -la "$FI" | tail
    exit 1
  }
  echo NINJA_OK
  ls -la "$FI"/*.so "$FI"/*.pyd 2>/dev/null || ls -la "$FI" | tail
else
  echo "no ninja dir $FI"
fi

echo "=== start nvfp4 0.80 ==="
QUANT=nvfp4 MEM=0.80 \
  EXTRA_ARGS='--disable-flashinfer-autotune --cuda-graph-max-bs 8 --mamba-full-memory-ratio 4.59' \
  ./sglang-start.sh
echo START_NVFP4_OK
