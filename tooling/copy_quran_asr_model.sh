#!/usr/bin/env bash
# copy_quran_asr_model.sh
#
# Copies the Quran ASR ONNX model from the POC model cache into
# the Flutter assets directory.  The model (~166 MB) is gitignored
# and must be present locally before building.
#
# Usage:
#   bash tooling/copy_quran_asr_model.sh
#
# Prerequisites:
#   The model must already be downloaded by running the Python POC:
#     cd docs/quran/murojaah/poc
#     pip install -r requirements.txt
#     python transcribe.py samples/test_ayat1.wav

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SRC_ONNX="${PROJECT_ROOT}/docs/quran/murojaah/poc/model_cache/onnx/model_int8.onnx"
SRC_VOCAB="${PROJECT_ROOT}/docs/quran/murojaah/poc/model_cache/tokenizer_vocab.json"
DST_DIR="${PROJECT_ROOT}/assets/models"

echo "=== Quran ASR model setup ==="
echo ""

# --- ONNX model ---
if [[ ! -f "${SRC_ONNX}" ]]; then
  echo "ERROR: ONNX model not found at:"
  echo "  ${SRC_ONNX}"
  echo ""
  echo "Download it first:"
  echo "  cd docs/quran/murojaah/poc"
  echo "  pip install -r requirements.txt"
  echo "  python transcribe.py samples/test_ayat1.wav"
  exit 1
fi

mkdir -p "${DST_DIR}"
cp "${SRC_ONNX}" "${DST_DIR}/model_int8.onnx"
MODEL_SIZE=$(du -sh "${DST_DIR}/model_int8.onnx" | cut -f1)
echo "Model:  ${DST_DIR}/model_int8.onnx  (${MODEL_SIZE})"

# --- Vocab (small JSON — always copy to keep in sync) ---
if [[ -f "${SRC_VOCAB}" ]]; then
  cp "${SRC_VOCAB}" "${DST_DIR}/tokenizer_vocab.json"
  VOCAB_SIZE=$(du -sh "${DST_DIR}/tokenizer_vocab.json" | cut -f1)
  echo "Vocab:  ${DST_DIR}/tokenizer_vocab.json  (${VOCAB_SIZE})"
else
  echo "WARN: tokenizer_vocab.json not found at ${SRC_VOCAB}"
fi

echo ""
echo "assets/models/*.onnx is .gitignored — do not commit the model binary."
echo "=== Done ==="
