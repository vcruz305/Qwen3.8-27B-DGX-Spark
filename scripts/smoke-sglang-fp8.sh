#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/victor/qwen38-speed/sglang
PY=/home/victor/work/sglang-venv/bin/python3
cd "$ROOT"
echo ===version===
"$PY" -c 'import sglang,flashinfer,torch; print("sglang", getattr(sglang,"__version__", "?")); print("flashinfer", getattr(flashinfer,"__version__","?")); print("torch", torch.__version__)'
echo ===warmup===
"$PY" ./vllm-smoke.py --base http://127.0.0.1:30000/v1 --model qwen3.8-27b --warmup-only
echo ===smoke===
"$PY" ./vllm-smoke.py --base http://127.0.0.1:30000/v1 --model qwen3.8-27b --label sglang-fp8-0.80
echo SMOKE_DONE
