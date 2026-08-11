/// quran_asr_result_test.dart
///
/// Unit tests for AsrInferenceResult and AsrTimings.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_portfolio/Quran/murojaah/infrastructure/asr/quran_asr_result.dart';

void main() {
  group('AsrTimings', () {
    test('totalMs excludes model load', () {
      const t = AsrTimings(
        modelLoadMs: 5000,
        preprocessMs: 100,
        inferenceMs: 200,
        decodeMs: 10,
      );
      expect(t.totalMs, equals(310));
    });

    test('toString contains all fields', () {
      const t = AsrTimings(
        modelLoadMs: 1000,
        preprocessMs: 50,
        inferenceMs: 150,
        decodeMs: 5,
      );
      final s = t.toString();
      expect(s, contains('load=1000ms'));
      expect(s, contains('preprocess=50ms'));
      expect(s, contains('inference=150ms'));
      expect(s, contains('decode=5ms'));
      expect(s, contains('total=205ms'));
    });
  });

  group('AsrInferenceResult', () {
    AsrInferenceResult _result({
      String transcript = 'test',
      double duration = 8.0,
      int inferenceMs = 800,
      int preprocessMs = 200,
      int decodeMs = 10,
    }) {
      return AsrInferenceResult(
        transcript: transcript,
        audioDurationSeconds: duration,
        timings: AsrTimings(
          modelLoadMs: 0,
          preprocessMs: preprocessMs,
          inferenceMs: inferenceMs,
          decodeMs: decodeMs,
        ),
      );
    }

    test('realtimeFactor = inferenceMs / (duration * 1000)', () {
      // 800ms inference / 8000ms audio = 0.1 RTF
      final r = _result(duration: 8.0, inferenceMs: 800);
      expect(r.realtimeFactor, closeTo(0.1, 1e-9));
    });

    test('fullRealtimeFactor = totalMs / (duration * 1000)', () {
      // totalMs = 200 + 800 + 10 = 1010ms, audio = 8000ms → 0.12625
      final r = _result(duration: 8.0, inferenceMs: 800, preprocessMs: 200, decodeMs: 10);
      expect(r.fullRealtimeFactor, closeTo(1010 / 8000.0, 1e-9));
    });

    test('realtimeFactor is 0 when duration is 0', () {
      final r = _result(duration: 0.0);
      expect(r.realtimeFactor, equals(0.0));
      expect(r.fullRealtimeFactor, equals(0.0));
    });

    test('RTF < 1.0 means faster-than-realtime', () {
      final r = _result(duration: 10.0, inferenceMs: 500);
      expect(r.realtimeFactor, lessThan(1.0));
    });

    test('toString contains transcript and duration', () {
      final r = _result(transcript: 'بِسْمِ اللَّهِ', duration: 3.5);
      final s = r.toString();
      expect(s, contains('بِسْمِ اللَّهِ'));
      expect(s, contains('3.50s'));
    });
  });
}
