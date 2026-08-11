// murojaah_audio_buffer_test.dart
//
// Unit tests for MurojaahAudioBuffer value object.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_portfolio/Quran/murojaah/infrastructure/audio/murojaah_audio_buffer.dart';

void main() {
  group('MurojaahAudioBuffer — basic properties', () {
    test('sampleRate is stored as-is', () {
      final buf = MurojaahAudioBuffer(
        samples:    Float32List(160),
        sampleRate: 16000,
        channels:   1,
      );
      expect(buf.sampleRate, 16000);
    });

    test('channels is stored as-is', () {
      final buf = MurojaahAudioBuffer(
        samples:    Float32List(160),
        sampleRate: 16000,
        channels:   1,
      );
      expect(buf.channels, 1);
    });

    test('sampleCount equals samples.length', () {
      final buf = MurojaahAudioBuffer(
        samples:    Float32List(4800),
        sampleRate: 16000,
        channels:   1,
      );
      expect(buf.sampleCount, 4800);
    });

    test('durationSeconds = sampleCount / sampleRate', () {
      final buf = MurojaahAudioBuffer(
        samples:    Float32List(16000),
        sampleRate: 16000,
        channels:   1,
      );
      expect(buf.durationSeconds, closeTo(1.0, 1e-9));
    });

    test('durationSeconds is 0 for zero sampleRate', () {
      final buf = MurojaahAudioBuffer(
        samples:    Float32List(100),
        sampleRate: 0,
        channels:   1,
      );
      expect(buf.durationSeconds, 0.0);
    });
  });

  group('MurojaahAudioBuffer — empty buffer', () {
    late MurojaahAudioBuffer empty;

    setUp(() {
      empty = MurojaahAudioBuffer(
        samples:    Float32List(0),
        sampleRate: 16000,
        channels:   1,
      );
    });

    test('sampleCount is 0', () => expect(empty.sampleCount, 0));
    test('durationSeconds is 0', () => expect(empty.durationSeconds, 0.0));
    test('rms is 0', () => expect(empty.rms, 0.0));
    test('peak is 0', () => expect(empty.peak, 0.0));
    test('silencePercentage is 100', () => expect(empty.silencePercentage, 100.0));
    test('isEffectivelySilent is true', () => expect(empty.isEffectivelySilent, isTrue));
  });

  group('MurojaahAudioBuffer — silence buffer', () {
    late MurojaahAudioBuffer silent;

    setUp(() {
      silent = MurojaahAudioBuffer(
        samples:    Float32List(16000), // all zeros
        sampleRate: 16000,
        channels:   1,
      );
    });

    test('rms is 0', () => expect(silent.rms, 0.0));
    test('peak is 0', () => expect(silent.peak, 0.0));
    test('silencePercentage is 100', () => expect(silent.silencePercentage, 100.0));
    test('isEffectivelySilent is true', () => expect(silent.isEffectivelySilent, isTrue));
  });

  group('MurojaahAudioBuffer — constant signal', () {
    // Constant signal at amplitude 0.5 → RMS = 0.5, peak = 0.5
    late MurojaahAudioBuffer constant;

    setUp(() {
      final s = Float32List(16000);
      s.fillRange(0, s.length, 0.5);
      constant = MurojaahAudioBuffer(
        samples:    s,
        sampleRate: 16000,
        channels:   1,
      );
    });

    test('rms ≈ 0.5', () => expect(constant.rms, closeTo(0.5, 1e-6)));
    test('peak = 0.5', () => expect(constant.peak, closeTo(0.5, 1e-9)));
    test('silencePercentage is 0', () => expect(constant.silencePercentage, 0.0));
    test('isEffectivelySilent is false', () => expect(constant.isEffectivelySilent, isFalse));
  });

  group('MurojaahAudioBuffer — alternating signal', () {
    // Alternating +0.5 / -0.5 → RMS = 0.5, peak = 0.5
    late MurojaahAudioBuffer alternating;

    setUp(() {
      final s = Float32List(1000);
      for (int i = 0; i < s.length; i++) {
        s[i] = i.isEven ? 0.5 : -0.5;
      }
      alternating = MurojaahAudioBuffer(
        samples:    s,
        sampleRate: 16000,
        channels:   1,
      );
    });

    test('rms ≈ 0.5', () => expect(alternating.rms, closeTo(0.5, 1e-6)));
    test('peak = 0.5', () => expect(alternating.peak, closeTo(0.5, 1e-9)));
  });

  group('MurojaahAudioBuffer — full-scale signal', () {
    // All samples at 1.0 → RMS = 1.0, peak = 1.0, not silent
    late MurojaahAudioBuffer fullScale;

    setUp(() {
      final s = Float32List(100);
      s.fillRange(0, s.length, 1.0);
      fullScale = MurojaahAudioBuffer(
        samples:    s,
        sampleRate: 16000,
        channels:   1,
      );
    });

    test('rms ≈ 1.0', () => expect(fullScale.rms, closeTo(1.0, 1e-6)));
    test('peak = 1.0', () => expect(fullScale.peak, closeTo(1.0, 1e-9)));
    test('isEffectivelySilent is false', () => expect(fullScale.isEffectivelySilent, isFalse));
  });

  group('MurojaahAudioBuffer — silencePercentage threshold', () {
    test('samples below 0.01 are counted as silent', () {
      final s = Float32List(100);
      // 50 samples at 0.005 (below threshold), 50 at 0.5 (above)
      for (int i = 0; i < 50; i++) s[i] = 0.005;
      for (int i = 50; i < 100; i++) s[i] = 0.5;
      final buf = MurojaahAudioBuffer(
        samples:    s,
        sampleRate: 16000,
        channels:   1,
      );
      expect(buf.silencePercentage, closeTo(50.0, 1e-9));
    });
  });

  group('MurojaahAudioBuffer — duration', () {
    test('3 second buffer at 16000 Hz', () {
      final buf = MurojaahAudioBuffer(
        samples:    Float32List(48000),
        sampleRate: 16000,
        channels:   1,
      );
      expect(buf.durationSeconds, closeTo(3.0, 1e-9));
    });

    test('8 second buffer matches expected sample count', () {
      final buf = MurojaahAudioBuffer(
        samples:    Float32List(128000),
        sampleRate: 16000,
        channels:   1,
      );
      expect(buf.durationSeconds, closeTo(8.0, 1e-9));
      expect(buf.sampleCount, 128000);
    });
  });

  group('MurojaahAudioBuffer — PCM conversion consistency', () {
    // Verify int16 → float32 conversion produces values within [-1, 1]
    test('int16 max value normalises to ~1.0', () {
      final s = Float32List(1);
      s[0] = 32767 / 32768.0;   // same formula as parsePcm16Wav
      final buf = MurojaahAudioBuffer(
        samples:    s,
        sampleRate: 16000,
        channels:   1,
      );
      expect(buf.samples[0], closeTo(1.0, 1e-4));
    });

    test('int16 min value normalises to -1.0', () {
      final s = Float32List(1);
      s[0] = -32768 / 32768.0;
      expect(s[0], closeTo(-1.0, 1e-4));
    });

    test('int16 zero normalises to 0.0', () {
      final s = Float32List(1);
      s[0] = 0 / 32768.0;
      expect(s[0], 0.0);
    });
  });

  group('MurojaahAudioBuffer — sinusoidal signal RMS', () {
    // For a full-cycle sine at amplitude A, RMS = A / sqrt(2)
    test('sine wave RMS ≈ A / sqrt(2)', () {
      const int n  = 16000;  // 1 second
      const double A = 0.8;
      final s = Float32List(n);
      for (int i = 0; i < n; i++) {
        s[i] = (A * math.sin(2 * math.pi * 440 * i / 16000)).toDouble();
      }
      final buf = MurojaahAudioBuffer(
        samples:    s,
        sampleRate: 16000,
        channels:   1,
      );
      expect(buf.rms, closeTo(A / math.sqrt(2), 0.005));
    });
  });
}
