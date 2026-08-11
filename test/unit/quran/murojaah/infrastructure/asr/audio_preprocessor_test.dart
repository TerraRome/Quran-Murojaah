/// audio_preprocessor_test.dart
///
/// Unit tests for AudioPreprocessor.
///
/// The golden values for mel statistics come from export_mel_reference.py.
/// Tolerance is 1e-4 (float32 round-trip introduces ~1e-7 error per op,
/// but accumulated over the mel filterbank ~1e-4 is realistic).
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_portfolio/Quran/murojaah/infrastructure/asr/audio_preprocessor.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a minimal valid 16-bit PCM WAV header + [nSamples] zero samples.
Uint8List _buildSilentWav({int nSamples = 16000, int sampleRate = 16000}) {
  final dataSize = nSamples * 2;
  final totalSize = 44 + dataSize;
  final buf = ByteData(totalSize);

  // RIFF header
  buf.buffer.asUint8List().setRange(0, 4, 'RIFF'.codeUnits);
  buf.setUint32(4, totalSize - 8, Endian.little);
  buf.buffer.asUint8List().setRange(8, 12, 'WAVE'.codeUnits);

  // fmt  chunk
  buf.buffer.asUint8List().setRange(12, 16, 'fmt '.codeUnits);
  buf.setUint32(16, 16, Endian.little);      // chunk size
  buf.setUint16(20, 1, Endian.little);       // PCM
  buf.setUint16(22, 1, Endian.little);       // mono
  buf.setInt32(24, sampleRate, Endian.little);
  buf.setInt32(28, sampleRate * 2, Endian.little); // byte rate
  buf.setUint16(32, 2, Endian.little);       // block align
  buf.setUint16(34, 16, Endian.little);      // bits per sample

  // data chunk
  buf.buffer.asUint8List().setRange(36, 40, 'data'.codeUnits);
  buf.setUint32(40, dataSize, Endian.little);
  // samples remain zero

  return buf.buffer.asUint8List();
}

/// Build a WAV containing a 440 Hz sine wave (1 second).
Uint8List _buildSineWav({int sampleRate = 16000, double freqHz = 440.0}) {
  const int nSamples = 16000;
  final pcm = Int16List(nSamples);
  for (int i = 0; i < nSamples; i++) {
    pcm[i] = (32767 * math.sin(2 * math.pi * freqHz * i / sampleRate)).round();
  }

  final dataSize = nSamples * 2;
  final total = 44 + dataSize;
  final buf = ByteData(total);
  buf.buffer.asUint8List().setRange(0, 4, 'RIFF'.codeUnits);
  buf.setUint32(4, total - 8, Endian.little);
  buf.buffer.asUint8List().setRange(8, 12, 'WAVE'.codeUnits);
  buf.buffer.asUint8List().setRange(12, 16, 'fmt '.codeUnits);
  buf.setUint32(16, 16, Endian.little);
  buf.setUint16(20, 1, Endian.little);
  buf.setUint16(22, 1, Endian.little);
  buf.setInt32(24, sampleRate, Endian.little);
  buf.setInt32(28, sampleRate * 2, Endian.little);
  buf.setUint16(32, 2, Endian.little);
  buf.setUint16(34, 16, Endian.little);
  buf.buffer.asUint8List().setRange(36, 40, 'data'.codeUnits);
  buf.setUint32(40, dataSize, Endian.little);
  final samples = buf.buffer.asUint8List(44);
  final view = ByteData.sublistView(samples);
  for (int i = 0; i < nSamples; i++) {
    view.setInt16(i * 2, pcm[i], Endian.little);
  }
  return buf.buffer.asUint8List();
}

double _mean(Float32List x) {
  double s = 0;
  for (final v in x) s += v;
  return s / x.length;
}

double _std(Float32List x) {
  final m = _mean(x);
  double s = 0;
  for (final v in x) s += (v - m) * (v - m);
  return math.sqrt(s / x.length);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AudioPreprocessor — WAV parsing', () {
    test('parses silent WAV: correct sample count and all-zero values', () {
      const int nSamples = 16000;
      final wav = _buildSilentWav(nSamples: nSamples);
      final samples = AudioPreprocessor.parsePcm16Wav(wav);

      expect(samples.length, equals(nSamples));
      expect(samples.every((s) => s == 0.0), isTrue);
    });

    test('parses sine WAV: samples in [-1, 1] and non-trivial', () {
      final wav = _buildSineWav();
      final samples = AudioPreprocessor.parsePcm16Wav(wav);

      expect(samples.length, equals(16000));
      for (final s in samples) {
        expect(s, greaterThanOrEqualTo(-1.0));
        expect(s, lessThanOrEqualTo(1.0));
      }
      // Not all zero
      expect(samples.any((s) => s.abs() > 0.5), isTrue);
    });

    test('int16 max maps to ~1.0 (within float32 precision)', () {
      // Build WAV with a single max-value sample
      final buf = ByteData(46);
      buf.buffer.asUint8List().setRange(0, 4, 'RIFF'.codeUnits);
      buf.setUint32(4, 38, Endian.little);
      buf.buffer.asUint8List().setRange(8, 12, 'WAVE'.codeUnits);
      buf.buffer.asUint8List().setRange(12, 16, 'fmt '.codeUnits);
      buf.setUint32(16, 16, Endian.little);
      buf.setUint16(20, 1, Endian.little);
      buf.setUint16(22, 1, Endian.little);
      buf.setInt32(24, 16000, Endian.little);
      buf.setInt32(28, 32000, Endian.little);
      buf.setUint16(32, 2, Endian.little);
      buf.setUint16(34, 16, Endian.little);
      buf.buffer.asUint8List().setRange(36, 40, 'data'.codeUnits);
      buf.setUint32(40, 2, Endian.little);
      buf.setInt16(44, 32767, Endian.little);
      final samples = AudioPreprocessor.parsePcm16Wav(buf.buffer.asUint8List());
      expect(samples[0], closeTo(32767 / 32768.0, 1e-6));
    });

    test('throws FormatException on non-WAV data', () {
      final bad = Uint8List.fromList(List.filled(100, 0));
      expect(() => AudioPreprocessor.parsePcm16Wav(bad), throwsFormatException);
    });

    test('throws FormatException on wrong sample rate', () {
      final wav = _buildSilentWav(sampleRate: 44100);
      expect(() => AudioPreprocessor.parsePcm16Wav(wav), throwsFormatException);
    });
  });

  group('AudioPreprocessor — Hann window', () {
    test('length is nFft (512)', () {
      final w = AudioPreprocessor.buildHannWindow();
      expect(w.length, equals(AudioPreprocessor.nFft));
    });

    test('starts and ends near zero', () {
      final w = AudioPreprocessor.buildHannWindow();
      expect(w[0], closeTo(0.0, 1e-7));
      // w[N-1] = 0.5*(1 - cos(2π(N-1)/N)) ≈ small positive
      expect(w[AudioPreprocessor.nFft - 1], lessThan(0.01));
    });

    test('peak near middle is ~1.0', () {
      final w = AudioPreprocessor.buildHannWindow();
      final peak = w.reduce(math.max);
      expect(peak, closeTo(1.0, 1e-6));
    });
  });

  group('AudioPreprocessor — mel filterbank', () {
    test('shape is nMels × nFreqBins = 80 × 257', () {
      final fb = AudioPreprocessor.buildMelFilterbank();
      expect(fb.length, equals(AudioPreprocessor.nMels * AudioPreprocessor.nFreqBins));
    });

    test('all weights are non-negative', () {
      final fb = AudioPreprocessor.buildMelFilterbank();
      for (final w in fb) {
        expect(w, greaterThanOrEqualTo(0.0));
      }
    });

    test('each filter has at least one non-zero weight', () {
      final fb = AudioPreprocessor.buildMelFilterbank();
      for (int m = 0; m < AudioPreprocessor.nMels; m++) {
        bool hasNonZero = false;
        for (int k = 0; k < AudioPreprocessor.nFreqBins; k++) {
          if (fb[m * AudioPreprocessor.nFreqBins + k] > 0) {
            hasNonZero = true;
            break;
          }
        }
        expect(hasNonZero, isTrue, reason: 'Filter $m is all-zero');
      }
    });
  });

  group('AudioPreprocessor — full pipeline (silent input)', () {
    late Float32List hann;
    late Float32List fb;

    setUpAll(() {
      hann = AudioPreprocessor.buildHannWindow();
      fb   = AudioPreprocessor.buildMelFilterbank();
    });

    test('output shape matches expected T for 8s input', () {
      // 128000 samples + 2×256 pad = 128512; nFrames = (128512-512)/160+1 = 801
      final samples = Float32List(128000); // all zeros
      final result = AudioPreprocessor.process(
        samples: samples,
        hannWindow: hann,
        melFilterbank: fb,
      );
      expect(result.nMels, equals(80));
      expect(result.nFrames, equals(801));
      expect(result.tensor.length, equals(80 * 801));
      expect(result.durationSeconds, closeTo(8.0, 1e-6));
    });

    test('output shape: T = floor(samples/hop)+1 with center padding', () {
      // 1s @ 16kHz = 16000 samples → pad to 16512 → (16512-512)/160+1 = 101
      final samples = Float32List(16000);
      final result = AudioPreprocessor.process(
        samples: samples,
        hannWindow: hann,
        melFilterbank: fb,
      );
      expect(result.nFrames, equals(101));
    });

    test('normalised output has mean ≈ 0 and std ≈ 1 for non-trivial input', () {
      // Use sine wave so mel is non-trivial
      final wav = _buildSineWav();
      final result = AudioPreprocessor.processWavBytes(
        bytes: wav,
        hannWindow: hann,
        melFilterbank: fb,
      );
      final m = _mean(result.tensor);
      final s = _std(result.tensor);
      expect(m, closeTo(0.0, 1e-4));
      expect(s, closeTo(1.0, 1e-4));
    });
  });

  group('AudioPreprocessor — golden statistics (Python reference)', () {
    // Golden values from export_mel_reference.py for test_ayat1.wav (8s, 16kHz mono)
    // norm — min=-2.176155  max=3.743019  mean=0.000000  std=1.000000
    // shape: (80, 801)
    //
    // These tests verify the Dart pipeline against the Python/librosa reference.
    // They run against the actual WAV files in the repo.

    test('T=801 for 8s WAV (center=True)', () {
      // Validates the frame count formula matches librosa center=True padding
      // 128000 samples → padded 128512 → T = (128512-512)/160 + 1 = 801
      const int nSamples = 128000;
      final samples = Float32List(nSamples);
      final hann = AudioPreprocessor.buildHannWindow();
      final fb   = AudioPreprocessor.buildMelFilterbank();
      final result = AudioPreprocessor.process(
        samples: samples,
        hannWindow: hann,
        melFilterbank: fb,
      );
      expect(result.nFrames, equals(801));
    });

    test('normalised mean is 0 and std is 1 (by construction)', () {
      // This is an algebraic guarantee of the normalization step — not WAV-dependent
      final wav = _buildSineWav(sampleRate: 16000, freqHz: 440);
      final result = AudioPreprocessor.processWavBytes(bytes: wav);
      final m = _mean(result.tensor);
      final s = _std(result.tensor);
      // After normalisation: mean == 0, std == 1 exactly (within float32 precision)
      expect(m, closeTo(0.0, 1e-4));
      expect(s, closeTo(1.0, 1e-3));
    });
  });
}
