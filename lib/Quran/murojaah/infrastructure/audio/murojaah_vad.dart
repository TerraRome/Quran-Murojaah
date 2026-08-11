/// murojaah_vad.dart
///
/// Abstract VAD (Voice Activity Detection) interface for the Murojaah
/// utterance segmentation pipeline.
///
/// Implementations receive a short Float32 PCM frame and classify whether
/// that frame contains speech-level energy.
///
/// The interface is intentionally minimal so it can be replaced by a proper
/// ML-based VAD (e.g. Silero VAD) later without changing the segmenter.
library murojaah_vad;

import 'dart:typed_data';

/// Stateless per-frame speech/silence classifier.
///
/// The caller is responsible for slicing the audio stream into frames of the
/// appropriate duration before calling [isSpeech].
///
/// Contract:
/// - [samples] are Float32 PCM, normalized to ±1.0
/// - Returns `true`  → frame contains speech-level energy
/// - Returns `false` → frame is silence or sub-threshold noise
/// - Must be deterministic for the same input
/// - Must NOT have internal mutable state that changes across frames
///   (stateless per-frame classification)
abstract interface class MurojaahVad {
  /// Returns `true` if [samples] appear to contain speech-level energy.
  ///
  /// [samples] must be Float32 PCM, normalized to ±1.0, at the sample rate
  /// configured when the VAD was constructed.
  bool isSpeech(Float32List samples);
}
