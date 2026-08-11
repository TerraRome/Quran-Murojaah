// energy_vad_test.dart
//
// Unit tests for EnergyVad and VadConfig.
// All tests use synthetic Float32 PCM — no microphone, no platform channels.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_portfolio/Quran/murojaah/infrastructure/audio/energy_vad.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Generates a Float32List of [length] all-zero samples (silence).
Float32List _silence(int length) => Float32List(length);

/// Generates low-level noise at [amplitude] (below speech threshold).
Float32List _noise(int length, {double amplitude = 0.003}) {
  final s = Float32List(length);
  for (int i = 0; i < length; i++) {
    s[i] = (i % 2 == 0) ? amplitude : -amplitude;
  }
  return s;
}

/// Generates a synthetic speech-level signal at [amplitude].
Float32List _speech(int length, {double amplitude = 0.1}) {
  final s = Float32List(length);
  for (int i = 0; i < length; i++) {
    s[i] = amplitude * math.sin(2 * math.pi * 300 * i / 16000);
  }
  return s;
}

/// A single frame of [length] samples, all set to [value].
Float32List _constant(int length, double value) {
  final s = Float32List(length);
  for (int i = 0; i < length; i++) {
    s[i] = value;
  }
  return s;
}

void main() {
  // Default config used across most tests.
  const config = VadConfig(
    sampleRate: 16000,
    frameDurationMs: 20,
    speechThreshold: 0.015,
  );
  const vad = EnergyVad(config: config);

  // -------------------------------------------------------------------------
  // 1. RMS calculation
  // -------------------------------------------------------------------------

  group('EnergyVad.computeRms', () {
    test('empty samples → 0.0', () {
      expect(EnergyVad.computeRms(Float32List(0)), 0.0);
    });

    test('all-zero samples → 0.0', () {
      expect(EnergyVad.computeRms(_silence(320)), 0.0);
    });

    test('constant +1.0 samples → RMS = 1.0', () {
      expect(EnergyVad.computeRms(_constant(320, 1.0)), closeTo(1.0, 1e-6));
    });

    test('constant -1.0 samples → RMS = 1.0', () {
      expect(EnergyVad.computeRms(_constant(320, -1.0)), closeTo(1.0, 1e-6));
    });

    test('alternating +A / -A → RMS = A', () {
      // For a sequence +A, -A, +A, -A... each sample^2 = A^2, mean = A^2, sqrt = A.
      const a = 0.3;
      final s = Float32List(320);
      for (int i = 0; i < 320; i++) s[i] = (i % 2 == 0) ? a : -a;
      expect(EnergyVad.computeRms(s), closeTo(a, 1e-5));
    });

    test('sine wave RMS ≈ A / sqrt(2)', () {
      const a = 0.5;
      final s = _speech(16000, amplitude: a);
      expect(
        EnergyVad.computeRms(s),
        closeTo(a / math.sqrt(2), 0.005),
      );
    });

    test('single sample equals its absolute value', () {
      final s = Float32List(1);
      s[0] = 0.42;
      expect(EnergyVad.computeRms(s), closeTo(0.42, 1e-6));
    });
  });

  // -------------------------------------------------------------------------
  // 2. Peak calculation
  // -------------------------------------------------------------------------

  group('EnergyVad.computePeak', () {
    test('empty samples → 0.0', () {
      expect(EnergyVad.computePeak(Float32List(0)), 0.0);
    });

    test('all-zero → 0.0', () {
      expect(EnergyVad.computePeak(_silence(320)), 0.0);
    });

    test('mixed values → correct peak', () {
      final s = Float32List.fromList([0.1, -0.5, 0.3, -0.2]);
      expect(EnergyVad.computePeak(s), closeTo(0.5, 1e-6));
    });
  });

  // -------------------------------------------------------------------------
  // 3. isSpeech — silence / noise / speech
  // -------------------------------------------------------------------------

  group('EnergyVad.isSpeech', () {
    test('empty frame → false', () {
      expect(vad.isSpeech(Float32List(0)), isFalse);
    });

    test('zero / silence → false', () {
      expect(vad.isSpeech(_silence(320)), isFalse);
    });

    test('low-level noise (amplitude 0.003) → false', () {
      // RMS of alternating ±0.003 = 0.003 < threshold 0.015
      expect(vad.isSpeech(_noise(320, amplitude: 0.003)), isFalse);
    });

    test('noise just below threshold → false', () {
      // amplitude 0.014 → RMS ≈ 0.014 < 0.015
      expect(vad.isSpeech(_noise(320, amplitude: 0.014)), isFalse);
    });

    test('speech-level signal (amplitude 0.1) → true', () {
      // RMS of sine at 0.1 ≈ 0.071, well above 0.015
      expect(vad.isSpeech(_speech(320, amplitude: 0.1)), isTrue);
    });

    test('loud speech signal (amplitude 0.5) → true', () {
      expect(vad.isSpeech(_speech(320, amplitude: 0.5)), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // 4. Threshold boundary
  // -------------------------------------------------------------------------

  group('EnergyVad — threshold boundary', () {
    test('RMS exactly at threshold → true', () {
      // Create alternating signal whose RMS exactly equals threshold.
      const threshold = 0.015;
      final vadExact = EnergyVad(
        config: const VadConfig(speechThreshold: threshold),
      );
      // Alternating ±threshold → RMS = threshold.
      final s = Float32List(320);
      for (int i = 0; i < 320; i++) {
        s[i] = (i % 2 == 0) ? threshold : -threshold;
      }
      expect(vadExact.isSpeech(s), isTrue);
    });

    test('RMS just below threshold → false', () {
      const threshold = 0.015;
      const amplitude = 0.01499; // slightly below
      final vadCustom = EnergyVad(
        config: const VadConfig(speechThreshold: threshold),
      );
      final s = Float32List(320);
      for (int i = 0; i < 320; i++) {
        s[i] = (i % 2 == 0) ? amplitude : -amplitude;
      }
      expect(vadCustom.isSpeech(s), isFalse);
    });

    test('custom high threshold 0.5 — normal speech rejected', () {
      const vad2 = EnergyVad(
        config: VadConfig(speechThreshold: 0.5),
      );
      // speech amplitude 0.1 → RMS ≈ 0.071, below 0.5
      expect(vad2.isSpeech(_speech(320, amplitude: 0.1)), isFalse);
    });

    test('custom low threshold 0.001 — noise accepted', () {
      const vad2 = EnergyVad(
        config: VadConfig(speechThreshold: 0.001),
      );
      expect(vad2.isSpeech(_noise(320, amplitude: 0.003)), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // 5. Different frame lengths
  // -------------------------------------------------------------------------

  group('EnergyVad — frame lengths', () {
    for (final len in [160, 320, 480, 800]) {
      test('speech detected for frame length $len', () {
        expect(vad.isSpeech(_speech(len, amplitude: 0.1)), isTrue);
      });

      test('silence rejected for frame length $len', () {
        expect(vad.isSpeech(_silence(len)), isFalse);
      });
    }
  });

  // -------------------------------------------------------------------------
  // 6. VadConfig derived values
  // -------------------------------------------------------------------------

  group('VadConfig derived values', () {
    test('samplesPerFrame = sampleRate * frameDurationMs / 1000', () {
      const c = VadConfig(sampleRate: 16000, frameDurationMs: 20);
      expect(c.samplesPerFrame, 320);
    });

    test('samplesPerFrame for 30ms frame', () {
      const c = VadConfig(sampleRate: 16000, frameDurationMs: 30);
      expect(c.samplesPerFrame, 480);
    });

    test('preSpeechPaddingSamples', () {
      const c = VadConfig(sampleRate: 16000, preSpeechPaddingMs: 200);
      expect(c.preSpeechPaddingSamples, 3200);
    });

    test('postSpeechPaddingSamples', () {
      const c = VadConfig(sampleRate: 16000, postSpeechPaddingMs: 200);
      expect(c.postSpeechPaddingSamples, 3200);
    });

    test('maxUtteranceSamples', () {
      const c = VadConfig(sampleRate: 16000, maxUtteranceDurationMs: 15000);
      expect(c.maxUtteranceSamples, 240000);
    });

    test('endSilenceDurationMs', () {
      const c = VadConfig(frameDurationMs: 20, consecutiveSilenceFrames: 35);
      expect(c.endSilenceDurationMs, 700);
    });
  });
}
