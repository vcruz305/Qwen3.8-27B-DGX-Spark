#!/usr/bin/env bash
# Stop the host SGLang process started by sglang-start.sh.
set -euo pipefail
cd "$(dirname "$0")"
PID_FILE="${PID_FILE:-$PWD/.sglang.pid}"
if [[ ! -f "$PID_FILE" ]]; then
  echo "no pid file"
  exit 0
fi
PID="$(cat "$PID_FILE")"
if kill -0 "$PID" 2>/dev/null; then
  kill "$PID" || true
  for _ in $(seq 1 30); do
    kill -0 "$PID" 2>/dev/null || break
    sleep 1
  done
  if kill -0 "$PID" 2>/dev/null; then
    kill -9 "$PID" || true
  fi
  echo "stopped $PID"
else
  echo "stale pid $PID"
fi
rm -f "$PID_FILE"
