#!/usr/bin/env bash
# download_models.sh
#
# Downloads the Quran ASR ONNX model from Hugging Face into
# the Flutter assets directory. The model (~166 MB) is gitignored
# and must be present locally before building.
#
# Usage:
#   bash tooling/download_models.sh
#
# Prerequisites:
#   curl (pre-installed on macOS/Linux)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DST_DIR="${PROJECT_ROOT}/assets/models"

HF_BASE="https://huggingface.co/Saboorhsn/quran-stt-onnx/resolve/main"
MODEL_URL="${HF_BASE}/onnx/model_int8.onnx"
VOCAB_URL="${HF_BASE}/tokenizer_vocab.json"

echo "=== Quran ASR model setup ==="
echo ""

mkdir -p "${DST_DIR}"

# --- ONNX model ---
MODEL_DST="${DST_DIR}/model_int8.onnx"
if [[ -f "${MODEL_DST}" ]]; then
  echo "Model already exists, skipping download:"
  echo "  ${MODEL_DST}"
else
  echo "Downloading model_int8.onnx (~166 MB)..."
  curl -L --progress-bar -o "${MODEL_DST}" "${MODEL_URL}"
  MODEL_SIZE=$(du -sh "${MODEL_DST}" | cut -f1)
  echo "Model:  ${MODEL_DST}  (${MODEL_SIZE})"
fi

# --- Vocab JSON ---
VOCAB_DST="${DST_DIR}/tokenizer_vocab.json"
if [[ -f "${VOCAB_DST}" ]]; then
  echo "Vocab already exists, skipping download:"
  echo "  ${VOCAB_DST}"
else
  echo "Downloading tokenizer_vocab.json..."
  curl -L --progress-bar -o "${VOCAB_DST}" "${VOCAB_URL}"
  VOCAB_SIZE=$(du -sh "${VOCAB_DST}" | cut -f1)
  echo "Vocab:  ${VOCAB_DST}  (${VOCAB_SIZE})"
fi

echo ""
echo "assets/models/*.onnx is .gitignored — do not commit the model binary."
echo "=== Done ==="
