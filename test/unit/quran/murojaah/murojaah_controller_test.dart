/// Integration tests for MurojaahController.validateWithMatcher().
///
/// Tests cover:
///   - ACCEPT: correct recitation advances the verse
///   - REJECT: wrong transcript stays on current verse
///   - RETRY: one missing word in long verse stays on current verse
///   - Interim ASR (isFinal: false): does NOT advance the verse
///   - State getters: isAcceptedByMatcher, isRetry, isRejectedByMatcher
///   - incorrectAttempts counter
///   - clearFeedback clears murojaahDecision
///   - Full session: all verses accepted → completed phase
///
/// Verse data: Yasin 001–004 from matching_report.json golden set.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_portfolio/Quran/murojaah/application/murojaah_controller.dart';
import 'package:flutter_portfolio/Quran/murojaah/application/speech_recognizer.dart';
import 'package:flutter_portfolio/Quran/murojaah/domain/murojaah_matcher.dart';

import 'fakes/fake_speech_recognizer.dart';

// ---------------------------------------------------------------------------
// Verse constants (Yasin, same source as murojaah_matcher_test.dart)
// ---------------------------------------------------------------------------

const _surah = 36;
const _totalVerses = 4; // short session for test speed

/// Yasin 001 — single word, exact match expected.
const _v1Expected = 'يس';
const _v1Correct = 'يس';

/// Yasin 002 — two words with harakat variation expected.
const _v2Expected = 'وَالْقُرْآنِ الْحَكِيمِ';
const _v2Correct = 'وَالْقُرْآنِ الْحَكِيمِ';

/// Yasin 004 — three words with superscript alef variation.
const _v4Expected = 'عَلَىٰ صِرَاطٍ مُّسْتَقِيمٍ';
const _v4Correct = 'عَلَى صِرَاطٍ مُسْتَقِيمٍ'; // no superscript alef

/// Yasin 012 — long verse (16 words), one deletion → RETRY.
const _v12Expected =
    'إِنَّا نَحْنُ نُحْيِي الْمَوْتَىٰ وَنَكْتُبُ مَا قَدَّمُوا وَآثَارَهُمْ وَكُلَّ شَيْءٍ أَحْصَيْنَاهُ فِي إِمَامٍ مُّبِينٍ';
// One word deleted (الْمَوْتَى → الموتى mismatch handled by normalizer,
// but here we drop وَنَكْتُبُ to force a deletion in a long verse).
const _v12OneMissing =
    'إِنَّا نَحْنُ نُحْيِي الْمَوْتَىٰ مَا قَدَّمُوا وَآثَارَهُمْ وَكُلَّ شَيْءٍ أَحْصَيْنَاهُ فِي إِمَامٍ مُّبِينٍ';

/// Completely wrong transcript — guaranteed REJECT.
const _wrongTranscript = 'بسم الله الرحمن الرحيم';

void main() {
  // ─── Helpers ──────────────────────────────────────────────────────────────

  MurojaahController makeController() {
    final ctrl = MurojaahController();
    ctrl.start(surahNumber: _surah, totalVerses: _totalVerses);
    return ctrl;
  }

  // ─── ACCEPT ───────────────────────────────────────────────────────────────

  group('ACCEPT', () {
    test('correct recitation advances activeVerse from 1 to 2', () {
      final ctrl = makeController();
      expect(ctrl.value.activeVerse, 1);

      final advanced = ctrl.validateWithMatcher(
        transcript: _v1Correct,
        expectedArabic: _v1Expected,
        surahNumber: _surah,
        totalVerses: _totalVerses,
      );

      expect(advanced, isTrue);
      expect(ctrl.value.activeVerse, 2);
      expect(ctrl.value.isRunning, isTrue);
      expect(ctrl.value.isAcceptedByMatcher, isTrue);
      expect(ctrl.value.murojaahDecision, MurojaahDecision.accept);
    });

    test('incorrectAttempts resets to 0 after ACCEPT', () {
      final ctrl = makeController();

      // One wrong attempt first.
      ctrl.validateWithMatcher(
        transcript: _wrongTranscript,
        expectedArabic: _v1Expected,
        surahNumber: _surah,
        totalVerses: _totalVerses,
      );
      expect(ctrl.incorrectAttempts, 1);

      // Now correct.
      ctrl.validateWithMatcher(
        transcript: _v1Correct,
        expectedArabic: _v1Expected,
        surahNumber: _surah,
        totalVerses: _totalVerses,
      );
      expect(ctrl.incorrectAttempts, 0);
    });

    test('revealed count increments after each ACCEPT', () {
      final ctrl = makeController();
      expect(ctrl.revealedCount, 0);

      ctrl.validateWithMatcher(
        transcript: _v1Correct,
        expectedArabic: _v1Expected,
        surahNumber: _surah,
        totalVerses: _totalVerses,
      );
      expect(ctrl.revealedCount, 1);

      ctrl.validateWithMatcher(
        transcript: _v2Correct,
        expectedArabic: _v2Expected,
        surahNumber: _surah,
        totalVerses: _totalVerses,
      );
      expect(ctrl.revealedCount, 2);
    });

    test('session completes when all verses are accepted', () {
      final ctrl = makeController();

      final verses = [
        (_v1Correct, _v1Expected),
        (_v2Correct, _v2Expected),
        (_v4Correct, _v4Expected),
        // 4th verse: use exact match for simplicity.
        (_v1Correct, _v1Expected),
      ];

      for (final (transcript, expected) in verses) {
        ctrl.validateWithMatcher(
          transcript: transcript,
          expectedArabic: expected,
          surahNumber: _surah,
          totalVerses: _totalVerses,
        );
      }

      expect(ctrl.value.phase, MurojaahPhase.completed);
      expect(ctrl.revealedCount, _totalVerses);
    });
  });

  // ─── REJECT ───────────────────────────────────────────────────────────────

  group('REJECT', () {
    test('wrong transcript does not advance the verse', () {
      final ctrl = makeController();
      expect(ctrl.value.activeVerse, 1);

      final advanced = ctrl.validateWithMatcher(
        transcript: _wrongTranscript,
        expectedArabic: _v1Expected,
        surahNumber: _surah,
        totalVerses: _totalVerses,
      );

      expect(advanced, isFalse);
      expect(ctrl.value.activeVerse, 1);
      expect(ctrl.value.isRejectedByMatcher, isTrue);
      expect(ctrl.value.murojaahDecision, MurojaahDecision.reject);
    });

    test('incorrectAttempts increments on each REJECT', () {
      final ctrl = makeController();

      for (var i = 1; i <= 3; i++) {
        ctrl.validateWithMatcher(
          transcript: _wrongTranscript,
          expectedArabic: _v1Expected,
          surahNumber: _surah,
          totalVerses: _totalVerses,
        );
        expect(ctrl.incorrectAttempts, i);
      }
    });

    test('isRejectedByMatcher is true, isAcceptedByMatcher is false', () {
      final ctrl = makeController();

      ctrl.validateWithMatcher(
        transcript: _wrongTranscript,
        expectedArabic: _v1Expected,
        surahNumber: _surah,
        totalVerses: _totalVerses,
      );

      expect(ctrl.value.isRejectedByMatcher, isTrue);
      expect(ctrl.value.isAcceptedByMatcher, isFalse);
      expect(ctrl.value.isRetry, isFalse);
    });
  });

  // ─── RETRY ────────────────────────────────────────────────────────────────

  group('RETRY', () {
    test('one missing word in long verse does not advance', () {
      final ctrl = MurojaahController();
      // Use a 1-verse session with the long verse.
      ctrl.start(surahNumber: _surah, totalVerses: 1);

      final advanced = ctrl.validateWithMatcher(
        transcript: _v12OneMissing,
        expectedArabic: _v12Expected,
        surahNumber: _surah,
        totalVerses: 1,
      );

      expect(advanced, isFalse);
      expect(ctrl.value.isRetry, isTrue);
      expect(ctrl.value.murojaahDecision, MurojaahDecision.retry);
      expect(ctrl.value.isAcceptedByMatcher, isFalse);
      expect(ctrl.value.isRejectedByMatcher, isFalse);
    });

    test('RETRY increments incorrectAttempts', () {
      final ctrl = MurojaahController();
      ctrl.start(surahNumber: _surah, totalVerses: 1);
      expect(ctrl.incorrectAttempts, 0);

      ctrl.validateWithMatcher(
        transcript: _v12OneMissing,
        expectedArabic: _v12Expected,
        surahNumber: _surah,
        totalVerses: 1,
      );

      expect(ctrl.incorrectAttempts, 1);
    });
  });

  // ─── Interim ASR (isFinal: false) ─────────────────────────────────────────

  group('Interim ASR', () {
    test('isFinal:false does not advance the verse', () {
      final ctrl = makeController();
      expect(ctrl.value.activeVerse, 1);

      final advanced = ctrl.validateWithMatcher(
        transcript: _v1Correct,
        expectedArabic: _v1Expected,
        surahNumber: _surah,
        totalVerses: _totalVerses,
        isFinal: false,
      );

      expect(advanced, isFalse);
      expect(ctrl.value.activeVerse, 1, reason: 'verse must not advance on interim result');
    });

    test('isFinal:false does not change murojaahDecision', () {
      final ctrl = makeController();
      expect(ctrl.value.murojaahDecision, isNull);

      ctrl.validateWithMatcher(
        transcript: _v1Correct,
        expectedArabic: _v1Expected,
        surahNumber: _surah,
        totalVerses: _totalVerses,
        isFinal: false,
      );

      expect(ctrl.value.murojaahDecision, isNull,
          reason: 'interim result must not set murojaahDecision');
    });

    test('isFinal:false does not increment incorrectAttempts', () {
      final ctrl = makeController();

      ctrl.validateWithMatcher(
        transcript: _wrongTranscript,
        expectedArabic: _v1Expected,
        surahNumber: _surah,
        totalVerses: _totalVerses,
        isFinal: false,
      );

      expect(ctrl.incorrectAttempts, 0,
          reason: 'interim result must not count as a failed attempt');
    });

    test('final result after interim still works correctly', () {
      final ctrl = makeController();

      // Emit interim first — should be ignored.
      ctrl.validateWithMatcher(
        transcript: 'يـ',
        expectedArabic: _v1Expected,
        surahNumber: _surah,
        totalVerses: _totalVerses,
        isFinal: false,
      );
      expect(ctrl.value.activeVerse, 1);

      // Emit final — should advance.
      final advanced = ctrl.validateWithMatcher(
        transcript: _v1Correct,
        expectedArabic: _v1Expected,
        surahNumber: _surah,
        totalVerses: _totalVerses,
        isFinal: true,
      );

      expect(advanced, isTrue);
      expect(ctrl.value.activeVerse, 2);
    });
  });

  // ─── FakeSpeechRecognizer ─────────────────────────────────────────────────

  group('FakeSpeechRecognizer', () {
    test('initialize returns true when available', () async {
      final fake = FakeSpeechRecognizer();
      expect(await fake.initialize(), isTrue);
      expect(fake.isAvailable, isTrue);
      expect(fake.isInitialized, isTrue);
    });

    test('initialize returns false when unavailable', () async {
      final fake = FakeSpeechRecognizer(available: false);
      expect(await fake.initialize(), isFalse);
    });

    test('hasPermission reflects constructor argument', () async {
      final withPerm = FakeSpeechRecognizer(permission: true);
      final noPerm = FakeSpeechRecognizer(permission: false);
      expect(await withPerm.hasPermission, isTrue);
      expect(await noPerm.hasPermission, isFalse);
    });

    test('emitPartial delivers RecognizedSpeech with status listening', () async {
      final fake = FakeSpeechRecognizer();
      await fake.initialize();

      RecognizedSpeech? received;
      fake.listen(
        onResult: (s) => received = s,
        onError: (_) {},
      );

      fake.emitPartial('يس');

      expect(received, isNotNull);
      expect(received!.transcript, 'يس');
      expect(received!.status, SpeechRecognitionStatus.listening);
    });

    test('emitFinal delivers RecognizedSpeech with status recognized', () async {
      final fake = FakeSpeechRecognizer();
      await fake.initialize();

      RecognizedSpeech? received;
      fake.listen(
        onResult: (s) => received = s,
        onError: (_) {},
      );

      fake.emitFinal('وَالْقُرْآنِ الْحَكِيمِ');

      expect(received, isNotNull);
      expect(received!.transcript, 'وَالْقُرْآنِ الْحَكِيمِ');
      expect(received!.status, SpeechRecognitionStatus.recognized);
    });

    test('emitError delivers to onError callback', () async {
      final fake = FakeSpeechRecognizer();
      await fake.initialize();

      String? errorMsg;
      fake.listen(
        onResult: (_) {},
        onError: (m) => errorMsg = m,
      );

      fake.emitError('mic_unavailable');

      expect(errorMsg, 'mic_unavailable');
    });

    test('stop sets isListening to false', () async {
      final fake = FakeSpeechRecognizer();
      await fake.initialize();
      fake.listen(onResult: (_) {}, onError: (_) {});
      expect(fake.isListening, isTrue);
      await fake.stop();
      expect(fake.isListening, isFalse);
    });

    test('dispose clears callbacks and sets isDisposed', () async {
      final fake = FakeSpeechRecognizer();
      await fake.initialize();
      fake.listen(onResult: (_) {}, onError: (_) {});
      fake.dispose();
      expect(fake.isDisposed, isTrue);
      expect(fake.isListening, isFalse);
    });
  });

  // ─── clearFeedback ────────────────────────────────────────────────────────

  group('clearFeedback', () {
    test('clears murojaahDecision after REJECT', () {
      final ctrl = makeController();

      ctrl.validateWithMatcher(
        transcript: _wrongTranscript,
        expectedArabic: _v1Expected,
        surahNumber: _surah,
        totalVerses: _totalVerses,
      );
      expect(ctrl.value.murojaahDecision, MurojaahDecision.reject);

      ctrl.clearFeedback();
      expect(ctrl.value.murojaahDecision, isNull);
    });

    test('clearFeedback is no-op when no decision set', () {
      final ctrl = makeController();
      expect(ctrl.value.murojaahDecision, isNull);
      // Should not throw.
      ctrl.clearFeedback();
      expect(ctrl.value.murojaahDecision, isNull);
    });
  });

  // ─── FakeSpeechRecognizer → controller wiring ─────────────────────────────

  group('FakeSpeechRecognizer wired to controller', () {
    test('final result triggers ACCEPT and advances verse', () async {
      final fake = FakeSpeechRecognizer();
      await fake.initialize();

      final ctrl = makeController();

      // Wire: on final recognized result, run validateWithMatcher.
      fake.listen(
        onResult: (speech) {
          final isFinal = speech.status == SpeechRecognitionStatus.recognized;
          ctrl.validateWithMatcher(
            transcript: speech.transcript,
            expectedArabic: _v1Expected,
            surahNumber: _surah,
            totalVerses: _totalVerses,
            isFinal: isFinal,
          );
        },
        onError: (_) {},
      );

      // Partial → must not advance.
      fake.emitPartial('ي');
      expect(ctrl.value.activeVerse, 1);

      // Final → must advance.
      fake.emitFinal(_v1Correct);
      expect(ctrl.value.activeVerse, 2);
      expect(ctrl.value.isAcceptedByMatcher, isTrue);
    });

    test('final REJECT result does not advance verse', () async {
      final fake = FakeSpeechRecognizer();
      await fake.initialize();

      final ctrl = makeController();

      fake.listen(
        onResult: (speech) {
          final isFinal = speech.status == SpeechRecognitionStatus.recognized;
          ctrl.validateWithMatcher(
            transcript: speech.transcript,
            expectedArabic: _v1Expected,
            surahNumber: _surah,
            totalVerses: _totalVerses,
            isFinal: isFinal,
          );
        },
        onError: (_) {},
      );

      fake.emitFinal(_wrongTranscript);
      expect(ctrl.value.activeVerse, 1);
      expect(ctrl.value.isRejectedByMatcher, isTrue);
    });
  });
}
