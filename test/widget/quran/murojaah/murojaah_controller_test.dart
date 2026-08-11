import 'package:flutter_portfolio/Quran/murojaah/application/murojaah_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MurojaahController — reveal (Milestone 2)', () {
    test('awal: tidak ada ayat ter-reveal, ayat aktif 1', () {
      final controller = MurojaahController();
      expect(controller.revealedCount, 0);
      expect(controller.isRevealed(0), isFalse);
      expect(controller.nextActiveVerse(7), 1);
    });

    test('revealNext membuka ayat secara berurutan', () {
      final controller = MurojaahController();
      controller.revealNext(surahNumber: 112, totalVerses: 4);
      expect(controller.revealedCount, 1);
      expect(controller.isRevealed(0), isTrue);
      expect(controller.value.activeVerse, 2);

      controller.revealNext(surahNumber: 112, totalVerses: 4);
      controller.revealNext(surahNumber: 112, totalVerses: 4);
      expect(controller.revealedCount, 3);
      expect(controller.isRevealed(2), isTrue);

      controller.revealNext(surahNumber: 112, totalVerses: 4);
      expect(controller.revealedCount, 4);
      expect(controller.value.phase, MurojaahPhase.completed);
      expect(controller.nextActiveVerse(4), -1);
    });

    test('resetReveal menyembunyikan seluruh ayat kembali', () {
      final controller = MurojaahController();
      controller.revealNext(surahNumber: 112, totalVerses: 4);
      controller.revealNext(surahNumber: 112, totalVerses: 4);
      controller.resetReveal(surahNumber: 112, totalVerses: 4);
      expect(controller.revealedCount, 0);
      expect(controller.isRevealed(0), isFalse);
      expect(controller.value.activeVerse, 1);
      expect(controller.value.phase, MurojaahPhase.running);
    });

    test('revealNext setelah semua terbuka tidak berubah', () {
      final controller = MurojaahController();
      controller.revealNext(surahNumber: 1, totalVerses: 7);
      controller.revealNext(surahNumber: 1, totalVerses: 7);
      controller.revealNext(surahNumber: 1, totalVerses: 7);
      controller.revealNext(surahNumber: 1, totalVerses: 7);
      controller.revealNext(surahNumber: 1, totalVerses: 7);
      controller.revealNext(surahNumber: 1, totalVerses: 7);
      controller.revealNext(surahNumber: 1, totalVerses: 7);
      expect(controller.revealedCount, 7);
      controller.revealNext(surahNumber: 1, totalVerses: 7);
      expect(controller.revealedCount, 7);
    });
  });

  group('MurojaahController — state (Milestone 3)', () {
    test('start menyembunyikan seluruh ayat & menetapkan ayat aktif 1', () {
      final controller = MurojaahController();
      controller.start(surahNumber: 112, totalVerses: 4);
      expect(controller.value.phase, MurojaahPhase.running);
      expect(controller.value.activeVerse, 1);
      expect(controller.revealedCount, 0);
    });

    test('tryReveal menolak lompat urutan (validasi urutan)', () {
      final controller = MurojaahController();
      controller.start(surahNumber: 112, totalVerses: 4);

      expect(controller.tryReveal(2, surahNumber: 112, totalVerses: 4), isFalse);
      expect(controller.revealedCount, 0);
      expect(controller.value.activeVerse, 1);

      expect(controller.tryReveal(1, surahNumber: 112, totalVerses: 4), isTrue);
      expect(controller.revealedCount, 1);
      expect(controller.value.activeVerse, 2);
    });

    test('markCorrect reveal berurutan hingga completed', () {
      final controller = MurojaahController();
      controller.start(surahNumber: 112, totalVerses: 4);

      for (var expected = 1; expected <= 4; expected++) {
        controller.markCorrect(surahNumber: 112, totalVerses: 4);
        expect(controller.revealedCount, expected);
        expect(
          controller.value.activeVerse,
          expected == 4 ? isNull : expected + 1,
        );
      }
      expect(controller.value.phase, MurojaahPhase.completed);
      expect(controller.nextActiveVerse(4), -1);
    });

    test('markCorrect saat completed tidak mengubah apa pun', () {
      final controller = MurojaahController();
      controller.start(surahNumber: 112, totalVerses: 1);
      controller.markCorrect(surahNumber: 112, totalVerses: 1);
      expect(controller.value.phase, MurojaahPhase.completed);

      controller.markCorrect(surahNumber: 112, totalVerses: 1);
      expect(controller.revealedCount, 1);
      expect(controller.value.phase, MurojaahPhase.completed);
    });
  });

  group('MurojaahController — validate (Milestone 5)', () {
    const alIkhlas = 'قُلْ هُوَ ٱللَّهُ أَحَدٌ';

    test('transkrip benar → reveal, maju ke ayat 2, feedback correct', () {
      final controller = MurojaahController();
      controller.start(surahNumber: 112, totalVerses: 4);

      controller.validate(
        transcript: 'قل هو الله أحد',
        expectedArabic: alIkhlas,
        surahNumber: 112,
        totalVerses: 4,
      );

      expect(controller.revealedCount, 1);
      expect(controller.value.activeVerse, 2);
      expect(controller.value.feedback, MurojaahFeedback.correct);
    });

    test('transkrip salah → tetap di ayat aktif, feedback incorrect', () {
      final controller = MurojaahController();
      controller.start(surahNumber: 112, totalVerses: 4);

      controller.validate(
        transcript: 'قلم',
        expectedArabic: alIkhlas,
        surahNumber: 112,
        totalVerses: 4,
      );

      expect(controller.revealedCount, 0);
      expect(controller.value.activeVerse, 1);
      expect(controller.value.feedback, MurojaahFeedback.incorrect);
    });

    test('clearFeedback mengembalikan feedback ke none', () {
      final controller = MurojaahController();
      controller.start(surahNumber: 112, totalVerses: 4);
      controller.validate(
        transcript: 'قلم',
        expectedArabic: alIkhlas,
        surahNumber: 112,
        totalVerses: 4,
      );
      expect(controller.value.feedback, MurojaahFeedback.incorrect);

      controller.clearFeedback();
      expect(controller.value.feedback, MurojaahFeedback.none);
      expect(controller.value.activeVerse, 1);
      expect(controller.revealedCount, 0);
    });

    test('salah beruntun dihitung; benar/start mengreset counter', () {
      final controller = MurojaahController();
      controller.start(surahNumber: 112, totalVerses: 4);

      for (var i = 1; i <= 3; i++) {
        controller.validate(
          transcript: 'قلم',
          expectedArabic: alIkhlas,
          surahNumber: 112,
          totalVerses: 4,
        );
        expect(controller.incorrectAttempts, i);
      }
      expect(controller.needsHelp, isTrue);
      expect(controller.shouldTriggerHelp, isTrue); // percobaan ke-3
      expect(controller.value.activeVerse, 1); // tidak auto-lanjut

      // Percobaan benar mereset counter.
      controller.validate(
        transcript: 'قل هو الله أحد',
        expectedArabic: alIkhlas,
        surahNumber: 112,
        totalVerses: 4,
      );
      expect(controller.incorrectAttempts, 0);
      expect(controller.needsHelp, isFalse);
    });
  });
}