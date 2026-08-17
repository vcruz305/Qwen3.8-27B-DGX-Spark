#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
PID_FILE="${PID_FILE:-$PWD/.vllm.pid}"
if [[ ! -f "$PID_FILE" ]]; then
  echo "no $PID_FILE"
  exit 0
fi
PID="$(cat "$PID_FILE")"
if kill -0 "$PID" 2>/dev/null; then
  kill "$PID" || true
  sleep 2
  kill -9 "$PID" 2>/dev/null || true
  echo "stopped $PID"
else
  echo "stale pid $PID"
fi
rm -f "$PID_FILE"
