"""
export_mel_reference.py
=======================
Exports the Python/librosa mel spectrogram tensors for the two test WAV files
as .npy arrays so the Dart implementation can be validated against them.

Output files (gitignored):
  docs/quran/murojaah/poc/mel_ayat1.npy    shape (80, T)  — raw log-mel
  docs/quran/murojaah/poc/mel_ayat11.npy   shape (80, T)  — raw log-mel
  docs/quran/murojaah/poc/mel_norm_ayat1.npy   shape (80, T) — normalised
  docs/quran/murojaah/poc/mel_norm_ayat11.npy  shape (80, T) — normalised

The pipeline matches transcribe.py exactly:
  librosa.load(sr=16000, mono=True)
  librosa.feature.melspectrogram(
      n_fft=512, hop_length=160, n_mels=80, fmin=0.0, fmax=8000.0,
      center=True, pad_mode='constant', window='hann', power=2.0,
  )   →  filters: htk=False, norm='slaney'
  log(mel + 1e-9)
  per-utterance mean/std normalisation

Usage:
  cd docs/quran/murojaah/poc
  python export_mel_reference.py
"""

import os
import json
import numpy as np
import librosa

# ---------------------------------------------------------------------------
# Config — must match transcribe.py exactly
# ---------------------------------------------------------------------------
SAMPLE_RATE = 16000
N_FFT       = 512
HOP_LENGTH  = 160
N_MELS      = 80
FMIN        = 0.0
FMAX        = 8000.0
LOG_OFFSET  = 1e-9

POC_DIR   = os.path.dirname(os.path.abspath(__file__))
SAMPLES   = {
    "ayat1":  os.path.join(POC_DIR, "samples", "test_ayat1.wav"),
    "ayat11": os.path.join(POC_DIR, "samples", "ayat11.wav"),
}


def extract_log_mel(audio_path: str) -> tuple[np.ndarray, np.ndarray, float]:
    """Return (log_mel, log_mel_normalised, duration_seconds)."""
    # 1. Load — librosa defaults: center=True, pad_mode='constant' for STFT
    y, sr = librosa.load(audio_path, sr=SAMPLE_RATE, mono=True)
    duration = len(y) / sr

    # 2. Mel spectrogram (power=2.0 default, htk=False, norm='slaney' via filters.mel)
    mel = librosa.feature.melspectrogram(
        y=y,
        sr=sr,
        n_fft=N_FFT,
        hop_length=HOP_LENGTH,
        n_mels=N_MELS,
        fmin=FMIN,
        fmax=FMAX,
        center=True,
        pad_mode="constant",
        window="hann",
        power=2.0,
    )  # shape: (n_mels, T)

    # 3. Log compression
    log_mel = np.log(mel + LOG_OFFSET).astype(np.float32)

    # 4. Per-utterance normalisation
    mean = log_mel.mean()
    std  = log_mel.std()
    log_mel_norm = ((log_mel - mean) / (std + LOG_OFFSET)).astype(np.float32)

    return log_mel, log_mel_norm, duration


def main():
    print("=" * 60)
    print("Quran ASR — Python mel reference export")
    print(f"  sr={SAMPLE_RATE}, n_fft={N_FFT}, hop={HOP_LENGTH},",
          f"n_mels={N_MELS}, fmin={FMIN}, fmax={FMAX}")
    print(f"  center=True, pad_mode=constant, window=hann, power=2.0")
    print(f"  filters: htk=False, norm=slaney")
    print(f"  log_offset={LOG_OFFSET}")
    print("=" * 60)

    for tag, wav_path in SAMPLES.items():
        if not os.path.exists(wav_path):
            print(f"[SKIP] {wav_path} not found")
            continue

        log_mel, log_mel_norm, dur = extract_log_mel(wav_path)

        out_raw  = os.path.join(POC_DIR, f"mel_{tag}.npy")
        out_norm = os.path.join(POC_DIR, f"mel_norm_{tag}.npy")
        np.save(out_raw,  log_mel)
        np.save(out_norm, log_mel_norm)

        print(f"\n[{tag}]  {wav_path}")
        print(f"  duration  : {dur:.3f}s")
        print(f"  shape     : {log_mel.shape}  (n_mels={log_mel.shape[0]}, T={log_mel.shape[1]})")
        print(f"  raw  — min={log_mel.min():.6f}  max={log_mel.max():.6f}"
              f"  mean={log_mel.mean():.6f}  std={log_mel.std():.6f}")
        print(f"  norm — min={log_mel_norm.min():.6f}  max={log_mel_norm.max():.6f}"
              f"  mean={log_mel_norm.mean():.6f}  std={log_mel_norm.std():.6f}")
        print(f"  saved: {out_raw}")
        print(f"  saved: {out_norm}")

    print("\n[First 5x5 values of mel_norm_ayat1 — use as Dart unit-test fixture]")
    wav = SAMPLES["ayat1"]
    if os.path.exists(wav):
        _, norm, _ = extract_log_mel(wav)
        # Print first 5 rows × 5 cols for embedding in Dart tests
        for row in range(5):
            vals = [f"{norm[row, col]:12.8f}" for col in range(5)]
            print(f"  row[{row}]: {', '.join(vals)}")

    print("\nDone. .npy files are gitignored.")


if __name__ == "__main__":
    main()
