#!/usr/bin/env bash
# Official SGLang cookbook cell for Qwen3.8-27B on one DGX Spark (GB10).
# Cells: hw=dgx-spark variant=default strategy=balanced nodes=single
# QUANT=fp8  -> Qwen/Qwen3.8-27B-FP8
# QUANT=nvfp4 -> RadixArk/Qwen3.8-27B-NVFP4
set -euo pipefail
cd "$(dirname "$0")"

QUANT="${QUANT:-nvfp4}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-30000}"
ALIAS="${ALIAS:-qwen3.8-27b}"
MEM="${MEM:-0.95}"
CHUNK="${CHUNK:-8192}"
PID_FILE="${PID_FILE:-$PWD/.sglang.pid}"
LOG_FILE="${LOG_FILE:-$PWD/.sglang.log}"
SGLANG_BIN="${SGLANG_BIN:-$(command -v sglang || true)}"

case "$QUANT" in
  fp8)
    DEFAULT_TARGET="$PWD/models/fp8"
    DEFAULT_REPO="Qwen/Qwen3.8-27B-FP8"
    ;;
  nvfp4)
    DEFAULT_TARGET="$PWD/models/nvfp4-radix"
    DEFAULT_REPO="RadixArk/Qwen3.8-27B-NVFP4"
    ;;
  *)
    echo "QUANT must be fp8 or nvfp4" >&2
    exit 1
    ;;
esac

TARGET="${TARGET:-$DEFAULT_TARGET}"
REPO="${REPO:-$DEFAULT_REPO}"

if [[ -z "$SGLANG_BIN" ]]; then
  echo "sglang not on PATH — set SGLANG_BIN" >&2
  exit 1
fi
if [[ ! -d "$TARGET" ]] || [[ ! -f "$TARGET/config.json" ]]; then
  echo "missing target dir $TARGET (need config.json). download first:" >&2
  echo "  QUANT=$QUANT ./sglang-download.sh" >&2
  exit 1
fi

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "already running pid $(cat "$PID_FILE")  log $LOG_FILE"
  exit 0
fi
rm -f "$PID_FILE"

export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"
export PATH="$(dirname "$SGLANG_BIN"):${PATH}"
# Triton JIT needs Python.h. Spark image has empty /usr/include/python3.12 (no python3-dev).
# Vendor via scripts/vendor-python-headers.sh (no sudo).
if [[ -f /home/victor/opt/python3.12-dev/usr/include/python3.12/Python.h ]]; then
  # Need BOTH python3.12/ (for Python.h) and usr/include (for aarch64-linux-gnu/python3.12/pyconfig.h).
  export CPATH="/home/victor/opt/python3.12-dev/usr/include/python3.12:/home/victor/opt/python3.12-dev/usr/include:${CPATH:-}"
  export C_INCLUDE_PATH="$CPATH"
fi

echo "sglang $QUANT  $TARGET  mem=$MEM  chunk=$CHUNK  :$PORT"
# EXTRA_ARGS is optional (e.g. --disable-flashinfer-autotune on first Spark boot).
# shellcheck disable=SC2086
nohup "$SGLANG_BIN" serve \
  --trust-remote-code \
  --model-path "$TARGET" \
  --served-model-name "$ALIAS" \
  --mem-fraction-static "$MEM" \
  --attention-backend flashinfer \
  --chunked-prefill-size "$CHUNK" \
  --disable-prefill-cuda-graph \
  --reasoning-parser qwen3 \
  --tool-call-parser qwen3_coder \
  --host "$HOST" \
  --port "$PORT" \
  ${EXTRA_ARGS:-} \
  >"$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

READY="http://${HOST}:${PORT}/v1/models"
for _ in $(seq 1 240); do
  if curl -sf --max-time 2 "$READY" >/dev/null 2>&1; then
    echo "READY  $READY  pid $(cat "$PID_FILE")"
    echo "warmup: python3 ./vllm-smoke.py --base http://${HOST}:${PORT}/v1 --warmup-only"
    exit 0
  fi
  if ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "sglang died — last 80 log lines:" >&2
    tail -n 80 "$LOG_FILE" >&2
    exit 1
  fi
  sleep 5
done
echo "timeout waiting for $READY — tail $LOG_FILE" >&2
tail -n 80 "$LOG_FILE" >&2
exit 1
