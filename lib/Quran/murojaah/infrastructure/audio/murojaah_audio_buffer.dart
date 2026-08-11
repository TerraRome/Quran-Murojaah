/// murojaah_audio_buffer.dart
///
/// Immutable value object representing a captured audio utterance.
///
/// Holds normalized float32 PCM samples at 16 kHz mono — the exact format
/// consumed by [AudioPreprocessor.process].  No filesystem I/O is required
/// to feed this buffer into the preprocessing pipeline.
library murojaah_audio_buffer;

import 'dart:math' as math;
import 'dart:typed_data';

/// Immutable PCM audio buffer captured from the microphone.
///
/// Samples are normalized float32 in [-1.0, 1.0] at [sampleRate] Hz,
/// [channels] channels.  For the Quran ASR pipeline these are always
/// 16000 Hz / 1 channel.
class MurojaahAudioBuffer {
  /// Normalized float32 PCM samples, length == [sampleCount].
  final Float32List samples;

  /// Sample rate in Hz (always 16000 for the ASR pipeline).
  final int sampleRate;

  /// Number of channels (always 1 — mono).
  final int channels;

  MurojaahAudioBuffer({
    required this.samples,
    required this.sampleRate,
    required this.channels,
  });

  /// Number of samples.
  int get sampleCount => samples.length;

  /// Audio duration in seconds.
  double get durationSeconds =>
      sampleRate > 0 ? sampleCount / sampleRate.toDouble() : 0.0;

  /// Root-mean-square amplitude (0.0 = silence, 1.0 = full-scale).
  double get rms {
    if (samples.isEmpty) return 0.0;
    double sum = 0.0;
    for (final s in samples) {
      sum += s * s;
    }
    return math.sqrt(sum / samples.length);
  }

  /// Peak absolute amplitude.
  double get peak {
    if (samples.isEmpty) return 0.0;
    double p = 0.0;
    for (final s in samples) {
      final abs = s.abs();
      if (abs > p) p = abs;
    }
    return p;
  }

  /// Percentage of samples below the silence threshold (< 0.01 absolute).
  double get silencePercentage {
    if (samples.isEmpty) return 100.0;
    const double threshold = 0.01;
    int silentCount = 0;
    for (final s in samples) {
      if (s.abs() < threshold) silentCount++;
    }
    return silentCount / samples.length * 100.0;
  }

  /// Returns true when [rms] < 0.005 — useful for a quick silence check.
  bool get isEffectivelySilent => rms < 0.005;

  @override
  String toString() =>
      'MurojaahAudioBuffer('
      'sampleRate=${sampleRate}Hz '
      'channels=$channels '
      'sampleCount=$sampleCount '
      'duration=${durationSeconds.toStringAsFixed(2)}s '
      'rms=${rms.toStringAsFixed(4)} '
      'peak=${peak.toStringAsFixed(4)} '
      'silence=${silencePercentage.toStringAsFixed(1)}%'
      ')';
}
