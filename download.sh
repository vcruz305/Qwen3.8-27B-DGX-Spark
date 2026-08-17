#!/usr/bin/env bash
# Fetch one GGUF into ./models
# PACK=stock (default) or PACK=aeon
set -euo pipefail
cd "$(dirname "$0")"

PACK="${PACK:-stock}"
QUANT="${QUANT:-Q4_K_M}"

if [[ "$PACK" == "aeon" ]]; then
  REPO="${REPO:-vcruz305/Qwen3.8-27B-AEON-ULTIMATE-UNCENSORED-GGUF}"
  FILE="Qwen3.8-27B-AEON-ULTIMATE-UNCENSORED-${QUANT}.gguf"
else
  REPO="${REPO:-vcruz305/Qwen3.8-27B-GGUF}"
  FILE="Qwen3.8-27B-${QUANT}.gguf"
fi

OUT_DIR="${OUT_DIR:-$PWD/models}"
mkdir -p "$OUT_DIR"

if [[ -f "$OUT_DIR/$FILE" ]]; then
  echo "already have $OUT_DIR/$FILE"
  ls -lh "$OUT_DIR/$FILE"
  exit 0
fi

if [[ -z "${HF_TOKEN:-}" && -f "${HOME}/.cache/huggingface/token" ]]; then
  HF_TOKEN="$(tr -d '\n\r' < "${HOME}/.cache/huggingface/token")"
  export HF_TOKEN
fi

if command -v hf >/dev/null 2>&1; then
  DL=(hf download "$REPO" "$FILE" --local-dir "$OUT_DIR")
elif command -v huggingface-cli >/dev/null 2>&1; then
  DL=(huggingface-cli download "$REPO" "$FILE" --local-dir "$OUT_DIR")
else
  echo "need hf or huggingface-cli on PATH" >&2
  exit 1
fi

echo "download $REPO $FILE -> $OUT_DIR"
"${DL[@]}"
ls -lh "$OUT_DIR/$FILE"
echo DOWNLOAD-OK
