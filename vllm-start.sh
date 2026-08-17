#!/usr/bin/env bash
# Host vLLM for Qwen3.8-27B NVFP4 + DSpark on one DGX Spark (GB10).
# No Docker. Depth 14 is the measured winner on 9f73 (2026-08-16).
set -euo pipefail
cd "$(dirname "$0")"

TARGET="${TARGET:-$PWD/models/nvfp4}"
DRAFT="${DRAFT:-$PWD/models/dspark}"
VLLM_BIN="${VLLM_BIN:-$(command -v vllm || true)}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8002}"
ALIAS="${ALIAS:-qwen3.8-27b}"
DEPTH="${DEPTH:-14}"
CTX="${CTX:-262144}"
UTIL="${UTIL:-0.85}"
BATCH="${BATCH:-16384}"
PID_FILE="${PID_FILE:-$PWD/.vllm.pid}"
LOG_FILE="${LOG_FILE:-$PWD/.vllm.log}"

if [[ -z "$VLLM_BIN" ]]; then
  echo "vllm not on PATH — set VLLM_BIN" >&2
  exit 1
fi
if [[ ! -d "$TARGET" ]]; then
  echo "missing target dir $TARGET" >&2
  exit 1
fi
if [[ ! -d "$DRAFT" ]]; then
  echo "missing drafter dir $DRAFT" >&2
  exit 1
fi

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "already running pid $(cat "$PID_FILE")  log $LOG_FILE"
  exit 0
fi
rm -f "$PID_FILE"

# GB10 Marlin has a known race without this. Leave it on.
export VLLM_MARLIN_USE_ATOMIC_ADD=1
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"
export PATH="$(dirname "$VLLM_BIN"):${PATH}"

SPEC="$(python3 - <<PY
import json
print(json.dumps({
    "method": "dspark",
    "model": r"""$DRAFT""",
    "num_speculative_tokens": int("$DEPTH"),
    "draft_sample_method": "probabilistic",
}))
PY
)"

echo "vllm $TARGET  draft=$DRAFT  depth=$DEPTH  ctx=$CTX  :$PORT"
nohup "$VLLM_BIN" serve "$TARGET" \
  --served-model-name "$ALIAS" \
  --host "$HOST" --port "$PORT" \
  --max-model-len "$CTX" \
  --gpu-memory-utilization "$UTIL" \
  --max-num-batched-tokens "$BATCH" \
  --enable-prefix-caching \
  --speculative-config "$SPEC" \
  >"$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

READY="http://${HOST}:${PORT}/health"
for _ in $(seq 1 180); do
  if curl -sf --max-time 2 "$READY" >/dev/null 2>&1; then
    echo "READY  $READY  pid $(cat "$PID_FILE")"
    echo "warmup: python3 ./vllm-smoke.py --warmup-only"
    exit 0
  fi
  if ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "vllm died — last 80 log lines:" >&2
    tail -n 80 "$LOG_FILE" >&2
    exit 1
  fi
  sleep 4
done
echo "timeout waiting for $READY — tail $LOG_FILE" >&2
tail -n 80 "$LOG_FILE" >&2
exit 1
