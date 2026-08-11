/// streaming_record_audio_recorder_test.dart
///
/// Unit tests for logic associated with [StreamingRecordAudioRecorder].
///
/// SCOPE: Pure Dart logic only — no platform channels.
///
/// [StreamingRecordAudioRecorder] internally constructs [AudioRecorder],
/// which immediately registers a platform method channel
/// (`com.llfbandit.record/messages`).  Even with mocked channels,
/// [AudioRecorder.dispose] fires asynchronously after each test and
/// completes outside the mock's lifetime, causing leaked-async failures.
///
/// Rather than fighting the plugin's async disposal, this test file covers
/// only the pure-Dart logic that can be verified without platform channels:
///
///   1. int16 LE → float32 PCM conversion (identical algorithm used in
///      [StreamingRecordAudioRecorder.stop] and [RecordAudioRecorder.stop]).
///   2. [MurojaahAudioBuffer] construction and derived properties.
///
/// Lifecycle/stream tests that REQUIRE a real device or integration harness:
///   - instantiation (AudioRecorder() hits platform channel)
///   - initialize(), start(), stop(), dispose()
///   - isRecording state transitions
///   - audioStream emitting live chunks
///   - permission denied behaviour
///   - error propagation through the broadcast stream
///
/// See [VadPocPage] for manual end-to-end validation on device.

import 'dart:typed_data';

import 'package:flutter_portfolio/Quran/murojaah/infrastructure/audio/murojaah_audio_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers — mirror of the conversion logic in StreamingRecordAudioRecorder
// ---------------------------------------------------------------------------

/// Replicates the int16 LE → float32 conversion from
/// [StreamingRecordAudioRecorder.stop] so it can be tested in isolation.
Float32List _convertInt16ToFloat32(Uint8List bytes) {
  final nSamples = bytes.length ~/ 2;
  final samples  = Float32List(nSamples);
  final bd       = bytes.buffer.asByteData();
  for (int i = 0; i < nSamples; i++) {
    final int16val = bd.getInt16(i * 2, Endian.little);
    samples[i] = int16val / 32768.0;
  }
  return samples;
}

/// Encodes a list of int16 values as little-endian bytes.
Uint8List _encodeInt16LE(List<int> values) {
  final bytes = ByteData(values.length * 2);
  for (int i = 0; i < values.length; i++) {
    bytes.setInt16(i * 2, values[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── 1. PCM conversion — pure Dart, no platform dependency ────────────────

  group('int16 LE → float32 conversion', () {
    test('zero bytes → empty samples', () {
      final result = _convertInt16ToFloat32(Uint8List(0));
      expect(result, isEmpty);
    });

    test('positive max int16 (32767) → ~1.0', () {
      final bytes   = _encodeInt16LE([32767]);
      final samples = _convertInt16ToFloat32(bytes);
      expect(samples.length, 1);
      expect(samples[0], closeTo(32767 / 32768.0, 1e-6));
    });

    test('negative max int16 (-32768) → -1.0', () {
      final bytes   = _encodeInt16LE([-32768]);
      final samples = _convertInt16ToFloat32(bytes);
      expect(samples.length, 1);
      expect(samples[0], closeTo(-1.0, 1e-6));
    });

    test('zero int16 → 0.0', () {
      final bytes   = _encodeInt16LE([0]);
      final samples = _convertInt16ToFloat32(bytes);
      expect(samples[0], 0.0);
    });

    test('multiple samples converted correctly', () {
      final bytes   = _encodeInt16LE([0, 32767, -32768, 16384]);
      final samples = _convertInt16ToFloat32(bytes);
      expect(samples.length, 4);
      expect(samples[0], closeTo(0.0, 1e-6));
      expect(samples[1], closeTo(32767 / 32768.0, 1e-6));
      expect(samples[2], closeTo(-1.0, 1e-6));
      expect(samples[3], closeTo(16384 / 32768.0, 1e-6));
    });

    test('odd number of bytes → last byte ignored (integer division)', () {
      // 3 bytes → 1 sample (floor(3/2) = 1), last byte unused.
      final bytes   = Uint8List.fromList([0x00, 0x40, 0xFF]);
      final samples = _convertInt16ToFloat32(bytes);
      expect(samples.length, 1);
    });

    test('alternating ±amplitude produces correct mean-square', () {
      const amplitude = 16384; // 0.5 * 32768
      const n         = 320;
      final values    = List<int>.generate(n, (i) => i.isEven ? amplitude : -amplitude);
      final bytes     = _encodeInt16LE(values);
      final samples   = _convertInt16ToFloat32(bytes);

      double sum = 0.0;
      for (final s in samples) { sum += s * s; }
      final meanSquare = sum / samples.length;
      // Mean square of alternating ±A (normalized) = (A/32768)^2
      expect(
        meanSquare,
        closeTo(
          (amplitude / 32768.0) * (amplitude / 32768.0),
          1e-5,
        ),
      );
    });

    test('all-max-positive samples → all values ≈ 1.0', () {
      const n     = 64;
      final bytes = _encodeInt16LE(List.filled(n, 32767));
      final samples = _convertInt16ToFloat32(bytes);
      for (final s in samples) {
        expect(s, closeTo(32767 / 32768.0, 1e-6));
      }
    });

    test('all-min-negative samples → all values == -1.0', () {
      const n       = 64;
      final bytes   = _encodeInt16LE(List.filled(n, -32768));
      final samples = _convertInt16ToFloat32(bytes);
      for (final s in samples) {
        expect(s, closeTo(-1.0, 1e-6));
      }
    });

    test('output length is floor(input.length / 2)', () {
      for (final byteCount in [0, 1, 2, 3, 100, 101, 640]) {
        final bytes   = Uint8List(byteCount);
        final samples = _convertInt16ToFloat32(bytes);
        expect(samples.length, byteCount ~/ 2,
            reason: '$byteCount bytes → ${byteCount ~/ 2} samples');
      }
    });
  });

  // ── 2. MurojaahAudioBuffer construction ──────────────────────────────────

  group('MurojaahAudioBuffer from converted samples', () {
    test('correct sampleRate, channels, sampleCount', () {
      final bytes   = _encodeInt16LE([0, 1000, -1000]);
      final samples = _convertInt16ToFloat32(bytes);
      final buffer  = MurojaahAudioBuffer(
        samples:    samples,
        sampleRate: 16000,
        channels:   1,
      );
      expect(buffer.sampleRate,  16000);
      expect(buffer.channels,    1);
      expect(buffer.sampleCount, 3);
    });

    test('durationSeconds = sampleCount / sampleRate', () {
      // 16000 samples at 16 kHz = 1.0 second.
      final samples = Float32List(16000);
      final buffer  = MurojaahAudioBuffer(
        samples:    samples,
        sampleRate: 16000,
        channels:   1,
      );
      expect(buffer.durationSeconds, closeTo(1.0, 1e-9));
    });

    test('durationSeconds = 0.5 s for 8000 samples at 16 kHz', () {
      final samples = Float32List(8000);
      final buffer  = MurojaahAudioBuffer(
        samples:    samples,
        sampleRate: 16000,
        channels:   1,
      );
      expect(buffer.durationSeconds, closeTo(0.5, 1e-9));
    });

    test('silent buffer (all zeros) isEffectivelySilent', () {
      final samples = Float32List(320); // all zeros
      final buffer  = MurojaahAudioBuffer(
        samples:    samples,
        sampleRate: 16000,
        channels:   1,
      );
      expect(buffer.isEffectivelySilent, isTrue);
      expect(buffer.rms, 0.0);
    });

    test('non-silent buffer is not isEffectivelySilent', () {
      final bytes   = _encodeInt16LE(List.filled(320, 3277)); // ~0.1 amplitude
      final samples = _convertInt16ToFloat32(bytes);
      final buffer  = MurojaahAudioBuffer(
        samples:    samples,
        sampleRate: 16000,
        channels:   1,
      );
      expect(buffer.isEffectivelySilent, isFalse);
    });

    test('rms of full-scale signal is close to 1.0', () {
      final bytes   = _encodeInt16LE(
        List.generate(320, (i) => i.isEven ? 32767 : -32768),
      );
      final samples = _convertInt16ToFloat32(bytes);
      final buffer  = MurojaahAudioBuffer(
        samples:    samples,
        sampleRate: 16000,
        channels:   1,
      );
      expect(buffer.rms, closeTo(1.0, 0.01));
    });

    test('empty samples produce zero rms and durationSeconds', () {
      final buffer = MurojaahAudioBuffer(
        samples:    Float32List(0),
        sampleRate: 16000,
        channels:   1,
      );
      expect(buffer.rms,             0.0);
      expect(buffer.durationSeconds, 0.0);
      expect(buffer.sampleCount,     0);
    });
  });
}
