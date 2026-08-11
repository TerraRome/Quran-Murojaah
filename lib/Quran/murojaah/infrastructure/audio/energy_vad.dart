/// energy_vad.dart
///
/// RMS/energy-based implementation of [MurojaahVad].
///
/// Classifies a PCM frame as speech when its root-mean-square amplitude
/// exceeds [VadConfig.speechThreshold]. All parameters live in [VadConfig]
/// so they can be tuned without touching implementation logic.
///
/// Threshold rationale (measured on Android, voiceRecognition audio source):
///   - Background silence / ambient noise : RMS ≈ 0.000–0.004
///   - Normal conversational speech        : RMS ≈ 0.030–0.300
///   - Quran recitation (close-field mic)  : RMS ≈ 0.050–0.400
///
/// speechThreshold = 0.015 sits comfortably above the noise floor while
/// triggering on the quietest speech. Tune upward if false positives occur
/// in noisy environments.
library energy_vad;

import 'dart:math' as math;
import 'dart:typed_data';

import 'murojaah_vad.dart';

// ---------------------------------------------------------------------------
// Configuration value object
// ---------------------------------------------------------------------------

/// All tunable VAD + segmentation parameters in one place.
///
/// Pass a custom [VadConfig] to [EnergyVad] and [MurojaahUtteranceSegmenter]
/// to adjust behavior without modifying implementation code.
class VadConfig {
  const VadConfig({
    this.sampleRate = 16000,
    this.frameDurationMs = 20,
    this.speechThreshold = 0.015,
    this.consecutiveSpeechFrames = 3,
    this.consecutiveSilenceFrames = 35,
    this.preSpeechPaddingMs = 200,
    this.postSpeechPaddingMs = 200,
    this.maxUtteranceDurationMs = 8000,
  });

  /// Audio sample rate in Hz. Must match the recorder configuration (16000).
  final int sampleRate;

  /// Duration of each VAD frame in milliseconds.
  ///
  /// 20 ms → 320 samples @ 16 kHz.
  /// Shorter frames give finer time resolution; longer frames are cheaper.
  final int frameDurationMs;

  /// Minimum RMS amplitude to classify a frame as speech.
  ///
  /// 0.015 is chosen to sit well above the Android voiceRecognition source
  /// noise floor (≈ 0.002–0.004) while capturing even quiet recitation.
  /// Increase toward 0.03 if false positives occur in noisy environments.
  final double speechThreshold;

  /// Number of consecutive speech frames required before transitioning
  /// IDLE → SPEAKING.
  ///
  /// 3 frames × 20 ms = 60 ms minimum before entering SPEAKING.
  /// Prevents short clicks, breath pops, or single loud noise bursts from
  /// triggering utterance capture.
  final int consecutiveSpeechFrames;

  /// Number of consecutive silence frames required before transitioning
  /// SPEAKING → UTTERANCE_READY.
  ///
  /// 35 frames × 20 ms = 700 ms of silence before finalizing.
  /// Long enough to survive natural pauses between Quran phrases without
  /// prematurely splitting an utterance.
  final int consecutiveSilenceFrames;

  /// Audio to prepend before the first detected speech frame (ms).
  /// Captures the onset of the first syllable which may arrive before the
  /// speech detector triggers.
  final int preSpeechPaddingMs;

  /// Audio to append after the last detected speech frame (ms).
  /// Captures the tail of the last syllable and natural reverberation.
  final int postSpeechPaddingMs;

  /// Hard cap on utterance length in milliseconds.
  ///
  /// When the accumulated speaking buffer exceeds this duration, no new
  /// samples are appended. The segmenter then waits for natural silence to
  /// finalize. This caps peak memory usage at approximately:
  ///   15000 ms × 16000 samples/s × 4 bytes/sample = 960 KB
  final int maxUtteranceDurationMs;

  // ---------------------------------------------------------------------------
  // Derived values
  // ---------------------------------------------------------------------------

  /// Samples per VAD frame.
  int get samplesPerFrame => sampleRate * frameDurationMs ~/ 1000;

  /// Pre-speech padding in samples.
  int get preSpeechPaddingSamples => sampleRate * preSpeechPaddingMs ~/ 1000;

  /// Post-speech padding in samples.
  int get postSpeechPaddingSamples => sampleRate * postSpeechPaddingMs ~/ 1000;

  /// Maximum utterance length in samples.
  int get maxUtteranceSamples => sampleRate * maxUtteranceDurationMs ~/ 1000;

  /// End-silence duration in milliseconds (for display).
  int get endSilenceDurationMs => consecutiveSilenceFrames * frameDurationMs;

  @override
  String toString() =>
      'VadConfig('
      'sr=${sampleRate}Hz '
      'frame=${frameDurationMs}ms '
      'threshold=$speechThreshold '
      'speechFrames=$consecutiveSpeechFrames '
      'silenceFrames=$consecutiveSilenceFrames (${endSilenceDurationMs}ms) '
      'pre=${preSpeechPaddingMs}ms '
      'post=${postSpeechPaddingMs}ms '
      'maxDur=${maxUtteranceDurationMs}ms'
      ')';
}

// ---------------------------------------------------------------------------
// EnergyVad
// ---------------------------------------------------------------------------

/// Simple RMS-energy VAD.
///
/// Classifies a frame as speech when its RMS amplitude ≥ [VadConfig.speechThreshold].
///
/// This is intentionally a simple, stateless, dependency-free implementation.
/// It can be replaced by a Silero or WebRTC VAD by implementing [MurojaahVad]
/// without changing [MurojaahUtteranceSegmenter].
class EnergyVad implements MurojaahVad {
  const EnergyVad({this.config = const VadConfig()});

  final VadConfig config;

  /// Computes root-mean-square of [samples].
  ///
  /// Exposed as a static method so tests and diagnostics can reuse it
  /// independently of the VAD threshold.
  static double computeRms(Float32List samples) {
    if (samples.isEmpty) return 0.0;
    double sum = 0.0;
    for (final s in samples) {
      sum += s * s;
    }
    return math.sqrt(sum / samples.length);
  }

  /// Computes peak absolute amplitude of [samples].
  static double computePeak(Float32List samples) {
    if (samples.isEmpty) return 0.0;
    double peak = 0.0;
    for (final s in samples) {
      final abs = s.abs();
      if (abs > peak) peak = abs;
    }
    return peak;
  }

  @override
  bool isSpeech(Float32List samples) {
    if (samples.isEmpty) return false;
    return computeRms(samples) >= config.speechThreshold;
  }
}
