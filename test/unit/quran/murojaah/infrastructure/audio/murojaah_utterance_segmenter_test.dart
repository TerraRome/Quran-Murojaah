// murojaah_utterance_segmenter_test.dart
//
// Unit tests for MurojaahUtteranceSegmenter.
// All tests use synthetic Float32 PCM — no microphone, no platform channels.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_portfolio/Quran/murojaah/infrastructure/audio/energy_vad.dart';
import 'package:flutter_portfolio/Quran/murojaah/infrastructure/audio/murojaah_utterance_segmenter.dart';

// ---------------------------------------------------------------------------
// Test config — tight values so tests run quickly with small buffers
// ---------------------------------------------------------------------------

/// Fast config for testing:
/// - 20 ms frames = 320 samples
/// - 2 consecutive speech frames  → onset (40 ms)
/// - 5 consecutive silence frames → end   (100 ms)
/// - 100 ms pre-padding            = 1600 samples
/// - 100 ms post-padding           = 1600 samples
/// - 3 s max utterance             = 48000 samples
const _testConfig = VadConfig(
  sampleRate: 16000,
  frameDurationMs: 20,
  speechThreshold: 0.015,
  consecutiveSpeechFrames: 2,
  consecutiveSilenceFrames: 5,
  preSpeechPaddingMs: 100,
  postSpeechPaddingMs: 100,
  maxUtteranceDurationMs: 3000,
);

// ---------------------------------------------------------------------------
// PCM helpers
// ---------------------------------------------------------------------------

/// [n] frames of silence (all zeros), each frame = samplesPerFrame samples.
Float32List _silenceFrames(int n, {VadConfig config = _testConfig}) {
  return Float32List(n * config.samplesPerFrame);
}

/// [n] frames of speech-level signal (sine, amplitude 0.1).
Float32List _speechFrames(int n, {VadConfig config = _testConfig}) {
  final count = n * config.samplesPerFrame;
  final s = Float32List(count);
  for (int i = 0; i < count; i++) {
    s[i] = 0.1 * (i % 2 == 0 ? 1.0 : -1.0);
  }
  return s;
}

/// [n] frames of low-level noise (amplitude 0.003 — below threshold 0.015).
Float32List _noiseFrames(int n, {VadConfig config = _testConfig}) {
  final count = n * config.samplesPerFrame;
  final s = Float32List(count);
  for (int i = 0; i < count; i++) {
    s[i] = i % 2 == 0 ? 0.003 : -0.003;
  }
  return s;
}

/// Builds a fresh segmenter with the test config.
MurojaahUtteranceSegmenter _seg() =>
    MurojaahUtteranceSegmenter(config: _testConfig);

void main() {
  // -------------------------------------------------------------------------
  // 1. Initial state
  // -------------------------------------------------------------------------

  group('Initial state', () {
    test('starts in IDLE', () {
      expect(_seg().state, SegmenterState.idle);
    });

    test('totalSamples is 0', () {
      expect(_seg().totalSamples, 0);
    });

    test('finalizedUtteranceCount is 0', () {
      expect(_seg().finalizedUtteranceCount, 0);
    });

    test('currentRms is 0.0', () {
      expect(_seg().currentRms, 0.0);
    });

    test('consumeCompletedUtterance returns null when IDLE', () {
      expect(_seg().consumeCompletedUtterance(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 2. Empty input
  // -------------------------------------------------------------------------

  group('Empty input', () {
    test('addSamples with empty list → stays IDLE', () {
      final seg = _seg();
      seg.addSamples(Float32List(0));
      expect(seg.state, SegmenterState.idle);
    });

    test('addBytes with empty list → stays IDLE', () {
      final seg = _seg();
      seg.addBytes([]);
      expect(seg.state, SegmenterState.idle);
    });

    test('no utterance after empty input', () {
      final seg = _seg();
      seg.addSamples(Float32List(0));
      expect(seg.consumeCompletedUtterance(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 3. Silence only → no utterance
  // -------------------------------------------------------------------------

  group('Silence only', () {
    test('long silence → stays IDLE, no utterance', () {
      final seg = _seg();
      // 50 frames of silence = 1000 ms
      seg.addSamples(_silenceFrames(50));
      expect(seg.state, SegmenterState.idle);
      expect(seg.consumeCompletedUtterance(), isNull);
    });

    test('totalSamples is updated after silence', () {
      final seg = _seg();
      seg.addSamples(_silenceFrames(10));
      expect(seg.totalSamples, 10 * _testConfig.samplesPerFrame);
    });
  });

  // -------------------------------------------------------------------------
  // 4. Short noise burst → no utterance
  // -------------------------------------------------------------------------

  group('Short noise burst', () {
    test('1 noise frame (below threshold) → stays IDLE', () {
      final seg = _seg();
      // Even though it sounds like something, RMS < threshold → silence
      seg.addSamples(_noiseFrames(1));
      expect(seg.state, SegmenterState.idle);
    });

    test('1 speech frame (< consecutiveSpeechFrames=2) → stays IDLE', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(1));
      expect(seg.state, SegmenterState.idle);
    });

    test('speech then silence immediately → no utterance (not enough speech frames)', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(1)); // 1 frame, need 2
      seg.addSamples(_silenceFrames(10));
      expect(seg.state, SegmenterState.idle);
      expect(seg.consumeCompletedUtterance(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 5. Speech → silence → one utterance
  // -------------------------------------------------------------------------

  group('Speech → sustained silence → one utterance', () {
    test('transitions IDLE → SPEAKING after consecutiveSpeechFrames', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(2)); // exactly consecutiveSpeechFrames
      expect(seg.state, SegmenterState.speaking);
    });

    test('transitions SPEAKING → UTTERANCE_READY after sustained silence', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5)); // exactly consecutiveSilenceFrames
      expect(seg.state, SegmenterState.utteranceReady);
    });

    test('consumeCompletedUtterance returns non-null buffer', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      final buf = seg.consumeCompletedUtterance();
      expect(buf, isNotNull);
      expect(buf!.samples.isNotEmpty, isTrue);
    });

    test('returns to IDLE after consume', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      seg.consumeCompletedUtterance();
      expect(seg.state, SegmenterState.idle);
    });

    test('finalizedUtteranceCount increments on consume', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      seg.consumeCompletedUtterance();
      expect(seg.finalizedUtteranceCount, 1);
    });

    test('buffer sampleRate matches config', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      final buf = seg.consumeCompletedUtterance()!;
      expect(buf.sampleRate, _testConfig.sampleRate);
    });

    test('buffer channels is 1', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      final buf = seg.consumeCompletedUtterance()!;
      expect(buf.channels, 1);
    });
  });

  // -------------------------------------------------------------------------
  // 6. Speech → short silence → speech → one utterance (no premature split)
  // -------------------------------------------------------------------------

  group('Speech + short pause + speech → one utterance', () {
    test('short silence (< consecutiveSilenceFrames) does not finalize', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(3)); // only 3, need 5
      seg.addSamples(_speechFrames(3));
      // Should still be speaking, not finalized
      expect(seg.state, SegmenterState.speaking);
      expect(seg.consumeCompletedUtterance(), isNull);
    });

    test('after resumed speech + sustained silence → single utterance', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(3)); // short pause
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5)); // now finalize
      expect(seg.state, SegmenterState.utteranceReady);
      final buf = seg.consumeCompletedUtterance();
      expect(buf, isNotNull);
      expect(seg.finalizedUtteranceCount, 1);
    });
  });

  // -------------------------------------------------------------------------
  // 7. Two separate utterances → two segments
  // -------------------------------------------------------------------------

  group('Two separate utterances', () {
    test('produces two separate buffers', () {
      final seg = _seg();

      // First utterance
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      final buf1 = seg.consumeCompletedUtterance();

      // Second utterance
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      final buf2 = seg.consumeCompletedUtterance();

      expect(buf1, isNotNull);
      expect(buf2, isNotNull);
      expect(seg.finalizedUtteranceCount, 2);
    });

    test('state is IDLE between utterances', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      seg.consumeCompletedUtterance();
      expect(seg.state, SegmenterState.idle);
    });
  });

  // -------------------------------------------------------------------------
  // 8. Pre-speech padding preserved
  // -------------------------------------------------------------------------

  group('Pre-speech padding', () {
    test('utterance includes samples before speech onset', () {
      final seg = _seg();
      // Feed 5 frames of silence (will fill pre-buffer)
      seg.addSamples(_silenceFrames(5));
      // Then speech
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      final buf = seg.consumeCompletedUtterance()!;
      // Buffer should contain pre-padding (silence) + speech + post-padding
      // With 100ms pre-padding = 1600 samples, and 3 speech frames = 960 samples
      // plus post-padding, total should be > just the speech frames
      expect(buf.sampleCount, greaterThan(3 * _testConfig.samplesPerFrame));
    });

    test('utterance not empty when speech starts immediately', () {
      // Pre-buffer is empty on first speech — should degrade gracefully
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      final buf = seg.consumeCompletedUtterance();
      expect(buf, isNotNull);
      expect(buf!.sampleCount, greaterThan(0));
    });
  });

  // -------------------------------------------------------------------------
  // 9. Post-speech padding preserved
  // -------------------------------------------------------------------------

  group('Post-speech padding', () {
    test('utterance duration > speech-only frames', () {
      final seg = _seg();
      // 3 speech frames = 960 samples of actual speech
      final speechSamples = 3 * _testConfig.samplesPerFrame;
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      final buf = seg.consumeCompletedUtterance()!;
      // Should include at least some post-padding (up to 100ms)
      expect(buf.sampleCount, greaterThanOrEqualTo(speechSamples));
    });
  });

  // -------------------------------------------------------------------------
  // 10. Maximum duration protection
  // -------------------------------------------------------------------------

  group('Maximum duration protection', () {
    test('very long speech force-finalizes at maxUtteranceSamples (E2)', () {
      final seg = _seg();
      // Feed 200 frames of speech — far exceeds 3s max (= 48000 samples at 16kHz)
      // 200 frames × 320 samples = 64000 samples > 48000
      // E2: segmenter must force-finalize when buffer hits the cap — no silence needed.
      seg.addSamples(_speechFrames(200));
      expect(seg.state, SegmenterState.utteranceReady,
          reason: 'E2: max duration must force-finalize without silence');
      final buf = seg.consumeCompletedUtterance();
      expect(buf, isNotNull);
      expect(buf!.sampleCount, lessThanOrEqualTo(_testConfig.maxUtteranceSamples));
    });

    test('finalization still occurs after max duration when silence arrives', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(200)); // exceeds max
      seg.addSamples(_silenceFrames(5));  // sustained silence
      expect(seg.state, SegmenterState.utteranceReady);
      final buf = seg.consumeCompletedUtterance();
      expect(buf, isNotNull);
      // Buffer must not exceed max + post-padding
      expect(
        buf!.sampleCount,
        lessThanOrEqualTo(
          _testConfig.maxUtteranceSamples + _testConfig.postSpeechPaddingSamples,
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 11. Multiple arbitrary PCM chunk sizes
  // -------------------------------------------------------------------------

  group('Arbitrary chunk sizes', () {
    test('single-sample chunks produce same result as one large chunk', () {
      // Segmenter A: one large chunk
      final segA = _seg();
      final allSamples = Float32List.fromList([
        ..._speechFrames(3),
        ..._silenceFrames(5),
      ]);
      segA.addSamples(allSamples);
      final bufA = segA.consumeCompletedUtterance();

      // Segmenter B: one sample at a time
      final segB = _seg();
      for (int i = 0; i < allSamples.length; i++) {
        segB.addSamples(Float32List.fromList([allSamples[i]]));
      }
      final bufB = segB.consumeCompletedUtterance();

      expect(bufA, isNotNull);
      expect(bufB, isNotNull);
      expect(bufA!.sampleCount, bufB!.sampleCount);
    });

    test('odd-sized chunks work correctly', () {
      final seg = _seg();
      final allSamples = Float32List.fromList([
        ..._speechFrames(3),
        ..._silenceFrames(5),
      ]);
      // Feed in chunks of 100 (not aligned to frame boundary)
      for (int i = 0; i < allSamples.length; i += 100) {
        final end = (i + 100).clamp(0, allSamples.length);
        seg.addSamples(Float32List.sublistView(allSamples, i, end));
      }
      final buf = seg.consumeCompletedUtterance();
      expect(buf, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // 12. addBytes — int16 little-endian input
  // -------------------------------------------------------------------------

  group('addBytes (int16 PCM)', () {
    test('silence bytes → stays IDLE', () {
      final seg = _seg();
      // 10 frames × 320 samples × 2 bytes = 6400 bytes of silence
      final bytes = List<int>.filled(10 * _testConfig.samplesPerFrame * 2, 0);
      seg.addBytes(bytes);
      expect(seg.state, SegmenterState.idle);
    });

    test('speech-level int16 bytes → triggers SPEAKING', () {
      final seg = _seg();
      // Encode amplitude 0.1 as int16: 0.1 × 32767 ≈ 3277
      const int16Val = 3277;
      // 3 frames of speech
      final count = 3 * _testConfig.samplesPerFrame;
      final bytes = <int>[];
      for (int i = 0; i < count; i++) {
        final v = i % 2 == 0 ? int16Val : -int16Val;
        // Little-endian int16
        bytes.add(v & 0xFF);
        bytes.add((v >> 8) & 0xFF);
      }
      seg.addBytes(bytes);
      expect(seg.state, SegmenterState.speaking);
    });

    test('partial bytes buffered across calls', () {
      final seg = _seg();
      // One frame of silence = 320 samples × 2 bytes = 640 bytes
      // Feed 639 bytes (one short) then 1 more byte
      final allBytes = List<int>.filled(_testConfig.samplesPerFrame * 2, 0);
      seg.addBytes(allBytes.sublist(0, allBytes.length - 1));
      seg.addBytes(allBytes.sublist(allBytes.length - 1));
      // Should have processed exactly one frame
      expect(seg.totalSamples, _testConfig.samplesPerFrame);
    });
  });

  // -------------------------------------------------------------------------
  // 13. Reset
  // -------------------------------------------------------------------------

  group('reset()', () {
    test('returns to IDLE from SPEAKING', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      expect(seg.state, SegmenterState.speaking);
      seg.reset();
      expect(seg.state, SegmenterState.idle);
    });

    test('returns to IDLE from UTTERANCE_READY', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      expect(seg.state, SegmenterState.utteranceReady);
      seg.reset();
      expect(seg.state, SegmenterState.idle);
    });

    test('clears totalSamples', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(5));
      seg.reset();
      expect(seg.totalSamples, 0);
    });

    test('clears finalizedUtteranceCount', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      seg.consumeCompletedUtterance();
      seg.reset();
      expect(seg.finalizedUtteranceCount, 0);
    });

    test('no utterance available after reset', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      seg.reset();
      expect(seg.consumeCompletedUtterance(), isNull);
    });

    test('can produce new utterance after reset', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      seg.reset();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      final buf = seg.consumeCompletedUtterance();
      expect(buf, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // 14. consume clears completed utterance
  // -------------------------------------------------------------------------

  group('consumeCompletedUtterance clears state', () {
    test('second consume returns null', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      seg.consumeCompletedUtterance();
      expect(seg.consumeCompletedUtterance(), isNull);
    });

    test('state is IDLE after consume', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      seg.addSamples(_silenceFrames(5));
      seg.consumeCompletedUtterance();
      expect(seg.state, SegmenterState.idle);
    });
  });

  // -------------------------------------------------------------------------
  // 15. Diagnostics — currentRms and isSpeechDetected
  // -------------------------------------------------------------------------

  group('Live diagnostics', () {
    test('currentRms updates after addSamples', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(1));
      expect(seg.currentRms, greaterThan(0.0));
    });

    test('isSpeechDetected true during speech', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(2));
      expect(seg.isSpeechDetected, isTrue);
    });

    test('isSpeechDetected false after silence', () {
      final seg = _seg();
      seg.addSamples(_silenceFrames(2));
      expect(seg.isSpeechDetected, isFalse);
    });

    test('currentUtteranceDurationSeconds 0 when IDLE', () {
      final seg = _seg();
      expect(seg.currentUtteranceDurationSeconds, 0.0);
    });

    test('currentUtteranceDurationSeconds > 0 when SPEAKING', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(3));
      expect(seg.currentUtteranceDurationSeconds, greaterThan(0.0));
    });
  });

  // -------------------------------------------------------------------------
  // 16. Correct duration / sample count
  // -------------------------------------------------------------------------

  group('Buffer duration and sample count', () {
    test('buffer durationSeconds is positive', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(5));
      seg.addSamples(_silenceFrames(5));
      final buf = seg.consumeCompletedUtterance()!;
      expect(buf.durationSeconds, greaterThan(0.0));
    });

    test('buffer sampleCount > 0', () {
      final seg = _seg();
      seg.addSamples(_speechFrames(5));
      seg.addSamples(_silenceFrames(5));
      final buf = seg.consumeCompletedUtterance()!;
      expect(buf.sampleCount, greaterThan(0));
    });
  });
}
