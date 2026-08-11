/// quran_asr_result.dart
///
/// Value object returned by the ONNX ASR engine.
library quran_asr_result;

/// Timing breakdown for a single inference pass.
class AsrTimings {
  /// Milliseconds to load/warm-up the ONNX session (first call only).
  final int modelLoadMs;

  /// Milliseconds spent in WAV parsing + mel spectrogram computation.
  final int preprocessMs;

  /// Milliseconds spent in ONNX forward pass.
  final int inferenceMs;

  /// Milliseconds spent in CTC + BPE decoding.
  final int decodeMs;

  const AsrTimings({
    required this.modelLoadMs,
    required this.preprocessMs,
    required this.inferenceMs,
    required this.decodeMs,
  });

  /// Total wall-clock time (excluding model load).
  int get totalMs => preprocessMs + inferenceMs + decodeMs;

  @override
  String toString() =>
      'AsrTimings(load=${modelLoadMs}ms preprocess=${preprocessMs}ms '
      'inference=${inferenceMs}ms decode=${decodeMs}ms total=${totalMs}ms)';
}

/// Result of a single Quran ASR inference.
class AsrInferenceResult {
  /// Decoded Arabic transcript.
  final String transcript;

  /// Audio duration in seconds.
  final double audioDurationSeconds;

  /// Timing breakdown.
  final AsrTimings timings;

  const AsrInferenceResult({
    required this.transcript,
    required this.audioDurationSeconds,
    required this.timings,
  });

  /// Real-time factor: inferenceMs / (audioDurationSeconds * 1000).
  /// Values < 1.0 mean faster-than-real-time.
  double get realtimeFactor {
    if (audioDurationSeconds <= 0) return 0.0;
    return timings.inferenceMs / (audioDurationSeconds * 1000.0);
  }

  /// Full RTF including preprocessing and decoding.
  double get fullRealtimeFactor {
    if (audioDurationSeconds <= 0) return 0.0;
    return timings.totalMs / (audioDurationSeconds * 1000.0);
  }

  @override
  String toString() =>
      'AsrInferenceResult(transcript="$transcript" '
      'duration=${audioDurationSeconds.toStringAsFixed(2)}s '
      'rtf=${realtimeFactor.toStringAsFixed(3)} '
      '${timings})';
}
