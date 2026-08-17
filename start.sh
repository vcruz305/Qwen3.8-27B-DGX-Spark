#!/usr/bin/env bash
# llama-server for Qwen3.8-27B GGUF on one DGX Spark (GB10)
set -euo pipefail
cd "$(dirname "$0")"

PACK="${PACK:-stock}"
QUANT="${QUANT:-Q4_K_M}"
if [[ "$PACK" == "aeon" ]]; then
  DEFAULT_MODEL="$PWD/models/Qwen3.8-27B-AEON-ULTIMATE-UNCENSORED-${QUANT}.gguf"
  DEFAULT_ALIAS="qwen38-27b-aeon"
else
  DEFAULT_MODEL="$PWD/models/Qwen3.8-27B-${QUANT}.gguf"
  DEFAULT_ALIAS="qwen38-27b"
fi
MODEL="${MODEL:-$DEFAULT_MODEL}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8085}"
CTX="${CTX:-32768}"
ALIAS="${ALIAS:-$DEFAULT_ALIAS}"
PID_FILE="${PID_FILE:-$PWD/.llama.pid}"
LOG_FILE="${LOG_FILE:-$PWD/.llama.log}"
GPU="${CUDA_VISIBLE_DEVICES:-0}"

if [[ -z "${LLAMA_DIR:-}" ]]; then
  if [[ -x /home/victor/nemotron-quant/llama.cpp/build/bin/llama-server ]]; then
    LLAMA_DIR=/home/victor/nemotron-quant/llama.cpp/build/bin
  elif [[ -x /home/victor/qwen38-speed/bin/llama-server ]]; then
    LLAMA_DIR=/home/victor/qwen38-speed/bin
  else
    LLAMA_DIR=/home/victor/nemotron-quant/llama.cpp/build/bin
  fi
fi

SERVER="$LLAMA_DIR/llama-server"
if [[ ! -x "$SERVER" ]]; then
  echo "llama-server not executable at $SERVER" >&2
  echo "set LLAMA_DIR to a CUDA llama.cpp bin dir" >&2
  exit 1
fi
if [[ ! -f "$MODEL" ]]; then
  echo "missing $MODEL — run PACK=$PACK QUANT=$QUANT ./download.sh first" >&2
  exit 1
fi

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "already running pid $(cat "$PID_FILE")  log $LOG_FILE"
  exit 0
fi
rm -f "$PID_FILE"

export CUDA_VISIBLE_DEVICES="$GPU"
export LD_LIBRARY_PATH="${LLAMA_DIR}:/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"

CTK="${CTK:-}"
CTV="${CTV:-}"
KV_FLAGS=()
if [[ -n "$CTK" ]]; then KV_FLAGS+=(-ctk "$CTK"); fi
if [[ -n "$CTV" ]]; then KV_FLAGS+=(-ctv "$CTV"); fi

SPEC_FLAGS=()
if [[ "${SPEC:-}" == "mtp" ]]; then
  SPEC_FLAGS+=(--spec-type draft-mtp --spec-draft-n-max "${K:-2}" --spec-draft-p-min 0.7)
fi

echo "starting $MODEL on GPU $GPU  :$PORT  ctx=$CTX  pack=$PACK quant=$QUANT spec=${SPEC:-off}"
nohup "$SERVER" \
  -m "$MODEL" \
  -a "$ALIAS" \
  --host "$HOST" --port "$PORT" \
  -ngl 99 -fa on -c "$CTX" -np 1 -b 512 -ub 512 \
  "${KV_FLAGS[@]}" \
  "${SPEC_FLAGS[@]}" \
  --jinja --reasoning-format deepseek \
  >"$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

READY="http://127.0.0.1:${PORT}/health"
for i in $(seq 1 90); do
  if curl -sf --max-time 2 "$READY" >/dev/null 2>&1; then
    echo "READY  $READY  pid $(cat "$PID_FILE")"
    echo "curl http://127.0.0.1:${PORT}/v1/models"
    exit 0
  fi
  if ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "server died — last 80 log lines:" >&2
    tail -n 80 "$LOG_FILE" >&2
    exit 1
  fi
  sleep 2
done
echo "timeout waiting for $READY — tail $LOG_FILE" >&2
tail -n 80 "$LOG_FILE" >&2
exit 1
