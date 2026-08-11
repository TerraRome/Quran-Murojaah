"""
Quran STT ONNX POC
Model: Saboorhsn/quran-stt-onnx
Usage: python transcribe.py samples/test.mp3

Inference approach:
  - Download onnx/model_int8.onnx + tokenizer files from HuggingFace
  - Preprocess audio: resample to 16kHz mono, extract log-mel spectrogram
  - Run encoder ONNX -> encoder hidden states
  - Run decoder ONNX with greedy decoding -> token ids
  - Decode token ids with tokenizer_vocab.json
"""

import sys
import os
import json
import time

import numpy as np
import librosa
import soundfile as sf
import onnxruntime as ort
from huggingface_hub import hf_hub_download

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
REPO_ID = "Saboorhsn/quran-stt-onnx"
MODEL_FILE = "onnx/model_int8.onnx"
VOCAB_FILE = "tokenizer_vocab.json"
TOKENS_FILE = "tokens.txt"
SAMPLE_RATE = 16000
N_FFT = 512
HOP_LENGTH = 160
N_MELS = 80
CACHE_DIR = os.path.join(os.path.dirname(__file__), "model_cache")


def download_model():
    """Download model and tokenizer files from HuggingFace hub."""
    print("Downloading model files from HuggingFace (cached after first run)...")
    os.makedirs(CACHE_DIR, exist_ok=True)

    model_path = hf_hub_download(
        repo_id=REPO_ID,
        filename=MODEL_FILE,
        cache_dir=CACHE_DIR,
        local_dir=CACHE_DIR,
    )
    vocab_path = hf_hub_download(
        repo_id=REPO_ID,
        filename=VOCAB_FILE,
        cache_dir=CACHE_DIR,
        local_dir=CACHE_DIR,
    )
    tokens_path = hf_hub_download(
        repo_id=REPO_ID,
        filename=TOKENS_FILE,
        cache_dir=CACHE_DIR,
        local_dir=CACHE_DIR,
    )
    return model_path, vocab_path, tokens_path


def load_vocab(vocab_path, tokens_path):
    """Load id->token mapping.
    tokenizer_vocab.json format: {"pieces": [{"id": 0, "piece": "..."}, ...]}
    tokens.txt format: 'piece id' per line (space-separated, id on right)
    """
    id2tok = {}
    try:
        with open(vocab_path, encoding="utf-8") as f:
            vocab = json.load(f)
        # tokenizer_vocab.json has a "pieces" list of {"id": int, "piece": str}
        for entry in vocab.get("pieces", []):
            id2tok[entry["id"]] = entry["piece"]
        print(f"Loaded vocab: {len(id2tok)} tokens from tokenizer_vocab.json")
    except Exception as e:
        print(f"tokenizer_vocab.json failed ({e}), falling back to tokens.txt")

    if not id2tok:
        with open(tokens_path, encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if not line:
                    continue
                # format: 'piece id' — id is the last whitespace-separated token
                parts = line.rsplit(" ", 1)
                if len(parts) == 2:
                    piece, idx = parts[0], int(parts[1])
                else:
                    piece, idx = line, len(id2tok)
                id2tok[idx] = piece
        print(f"Loaded vocab: {len(id2tok)} tokens from tokens.txt")
    return id2tok


def load_audio(audio_path):
    """Load audio file, resample to 16kHz mono, return float32 numpy array."""
    audio, sr = librosa.load(audio_path, sr=SAMPLE_RATE, mono=True)
    duration = len(audio) / SAMPLE_RATE
    return audio, duration


def extract_features(audio):
    """
    Extract log-mel spectrogram features matching NeMo FastConformer preprocessing:
    - n_fft=512, hop_length=160, n_mels=80
    - log(mel + 1e-9), normalize per utterance
    Returns shape: (1, n_mels, time_frames)
    """
    mel = librosa.feature.melspectrogram(
        y=audio,
        sr=SAMPLE_RATE,
        n_fft=N_FFT,
        hop_length=HOP_LENGTH,
        n_mels=N_MELS,
        fmin=0.0,
        fmax=8000.0,
    )
    log_mel = np.log(mel + 1e-9).astype(np.float32)

    # Per-utterance mean/std normalization (NeMo default)
    log_mel = (log_mel - log_mel.mean()) / (log_mel.std() + 1e-9)

    # Shape: (1, n_mels, time_frames)
    return log_mel[np.newaxis, :, :]


def decode_tokens(token_ids, id2tok):
    """Convert token ids to text, joining BPE pieces."""
    tokens = [id2tok.get(int(i), f"<{i}>") for i in token_ids]
    # BPE pieces: NeMo SentencePiece uses ▁ as word boundary marker
    text = "".join(tokens).replace("▁", " ").strip()
    return text, tokens


def run_inference(model_path, features):
    """
    Run ONNX inference. Inspects the model's input/output names and shapes,
    then runs encoder-decoder or CTC depending on model type.
    Returns (token_ids, inference_time_seconds).
    """
    sess_options = ort.SessionOptions()
    sess_options.intra_op_num_threads = 4
    sess_options.inter_op_num_threads = 2

    print("Loading ONNX model...")
    session = ort.InferenceSession(
        model_path,
        sess_options=sess_options,
        providers=["CPUExecutionProvider"],
    )

    # Inspect model
    input_names = [inp.name for inp in session.get_inputs()]
    output_names = [out.name for out in session.get_outputs()]
    print(f"Model inputs:  {input_names}")
    print(f"Model outputs: {output_names}")

    # Build input dict — NeMo FastConformer ONNX expects:
    #   audio_signal: (batch, n_mels, time)
    #   length:       (batch,) — number of time frames
    time_frames = features.shape[2]
    length = np.array([time_frames], dtype=np.int64)

    feed = {}
    for inp in session.get_inputs():
        name = inp.name
        if "signal" in name or "input" in name or "audio" in name or "mel" in name:
            feed[name] = features
        elif "length" in name or "len" in name:
            feed[name] = length
        else:
            # Try to infer from shape
            shape = [d if isinstance(d, int) else 1 for d in inp.shape]
            feed[name] = np.zeros(shape, dtype=np.float32)

    t0 = time.perf_counter()
    outputs = session.run(output_names, feed)
    inference_time = time.perf_counter() - t0

    # Find the logits/token output
    # NeMo CTC models output log-probs: (batch, time, vocab) or (batch, vocab, time)
    logits = None
    for i, out in enumerate(session.get_outputs()):
        arr = outputs[i]
        if arr.ndim == 3:
            logits = arr
            print(f"Using output '{out.name}' shape {arr.shape} as logits")
            break

    if logits is None:
        # Fallback: use first output
        logits = outputs[0]
        print(f"Fallback: using output[0] shape {logits.shape}")

    # CTC greedy decode
    # If shape is (batch, time, vocab) — argmax over last axis
    if logits.ndim == 3:
        if logits.shape[2] > logits.shape[1]:
            # (batch, time, vocab) — standard
            ids = np.argmax(logits[0], axis=-1)
        else:
            # (batch, vocab, time) — transpose first
            ids = np.argmax(logits[0].T, axis=-1)
    else:
        ids = np.argmax(logits, axis=-1).flatten()

    # CTC collapse: remove blanks (id=0) and consecutive duplicates
    blank_id = 0
    collapsed = []
    prev = None
    for tok_id in ids:
        if tok_id != blank_id and tok_id != prev:
            collapsed.append(tok_id)
        prev = tok_id

    return collapsed, inference_time


def save_result(result, out_path):
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    print(f"\nResult saved to: {out_path}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python transcribe.py <audio_file>")
        sys.exit(1)

    audio_path = sys.argv[1]
    if not os.path.exists(audio_path):
        print(f"Error: file not found: {audio_path}")
        sys.exit(1)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    result_path = os.path.join(script_dir, "results", "test.json")

    print("=" * 60)
    print(f"Audio:\n{audio_path}\n")
    print(f"Model:\n{REPO_ID}\n")

    # 1. Download model
    model_path, vocab_path, tokens_path = download_model()

    # 2. Load vocab
    id2tok = load_vocab(vocab_path, tokens_path)

    # 3. Load audio
    print("Loading audio...")
    audio, duration = load_audio(audio_path)
    print(f"Audio duration:\n{duration:.2f} seconds\n")

    # 4. Extract features
    features = extract_features(audio)
    print(f"Feature shape: {features.shape}")

    # 5. Run inference
    token_ids, inference_time = run_inference(model_path, features)

    # 6. Decode
    transcript, tokens = decode_tokens(token_ids, id2tok)
    rtf = inference_time / duration if duration > 0 else 0

    print(f"Inference time:\n{inference_time:.2f} seconds\n")
    print(f"Realtime factor:\n{rtf:.3f}\n")
    print(f"Transcript:\n{transcript}\n")
    print(f"Raw tokens ({len(token_ids)}): {tokens[:30]}")

    # 7. Model file size
    model_size_mb = os.path.getsize(model_path) / (1024 * 1024)
    print(f"\nModel size: {model_size_mb:.1f} MB")

    # 8. Save result
    result = {
        "model": REPO_ID,
        "model_file": MODEL_FILE,
        "audio": audio_path,
        "audio_duration_seconds": round(duration, 3),
        "inference_time_seconds": round(inference_time, 3),
        "realtime_factor": round(rtf, 4),
        "transcript": transcript,
        "raw_token_count": len(token_ids),
        "model_size_mb": round(model_size_mb, 1),
    }
    save_result(result, result_path)
    print("=" * 60)


if __name__ == "__main__":
    main()
