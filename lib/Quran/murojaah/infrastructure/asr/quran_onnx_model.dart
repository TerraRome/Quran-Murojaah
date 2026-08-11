/// quran_onnx_model.dart
///
/// Abstract interface for the Quran ASR engine.
/// Implementations are free to use ONNX, a stub, or any other backend.
library quran_onnx_model;

import 'dart:typed_data';
import 'quran_asr_result.dart';

/// Abstract ASR engine for Quran recitation.
///
/// Implementations must be disposed after use via [dispose].
abstract class QuranAsrEngine {
  /// Pre-load the model and warm up inference ahead of the first call.
  ///
  /// Optional — implementations that do not support warm-up may provide a
  /// no-op. Callers must not rely on this completing before [transcribeSamples]
  /// is usable; it is best-effort pre-loading only.
  ///
  /// Must never throw — failures are silently swallowed by the caller.
  Future<void> warmUp() async {}

  /// Transcribe a 16-bit PCM WAV file (16 kHz, mono) from raw bytes.
  ///
  /// Returns an [AsrInferenceResult] containing the decoded transcript and
  /// timing information.
  Future<AsrInferenceResult> transcribeWav(Uint8List wavBytes);

  /// Transcribe normalized Float32 PCM samples (16 kHz, mono) directly.
  ///
  /// Skips WAV parsing — use this path when samples are already available
  /// as a [Float32List] (e.g. from [MurojaahAudioBuffer.samples]).
  ///
  /// [durationSeconds] is the audio duration in seconds, used for RTF
  /// calculation in the returned [AsrInferenceResult].
  Future<AsrInferenceResult> transcribeSamples(
    Float32List samples, {
    required double durationSeconds,
  });

  /// Release native resources (ONNX session, etc.).
  Future<void> dispose();
}
