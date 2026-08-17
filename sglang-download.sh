#!/usr/bin/env bash
# Download official SGLang cookbook checkpoints for one Spark.
# QUANT=fp8  -> Qwen/Qwen3.8-27B-FP8
# QUANT=nvfp4 -> RadixArk/Qwen3.8-27B-NVFP4
set -euo pipefail
cd "$(dirname "$0")"

QUANT="${QUANT:-nvfp4}"
case "$QUANT" in
  fp8)
    REPO="${REPO:-Qwen/Qwen3.8-27B-FP8}"
    DEST="${DEST:-$PWD/models/fp8}"
    ;;
  nvfp4)
    REPO="${REPO:-RadixArk/Qwen3.8-27B-NVFP4}"
    DEST="${DEST:-$PWD/models/nvfp4-radix}"
    ;;
  *)
    echo "QUANT must be fp8 or nvfp4" >&2
    exit 1
    ;;
esac

PY="${PY:-$(command -v python3)}"
mkdir -p "$(dirname "$DEST")"
echo "download $REPO -> $DEST"
"$PY" - <<PY
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id="${REPO}",
    local_dir="${DEST}",
    local_dir_use_symlinks=False,
)
print("OK", "${DEST}")
PY
ls -lh "$DEST" | head
test -f "$DEST/config.json"
echo DOWNLOAD_OK
