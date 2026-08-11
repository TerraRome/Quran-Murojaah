import 'package:flutter_portfolio/Quran/murojaah/application/arabic_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArabicMatcher.normalize', () {
    test('buang harakat (tashkeel)', () {
      expect(ArabicMatcher.normalize('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ'),
          'بسم الله الرحمن الرحيم');
    });

    test('normalisasi varian huruf (أ/إ/آ/ٱ/ى/ة/ؤ/ئ/ء)', () {
      expect(ArabicMatcher.normalize('آمن'), 'امن');
      expect(ArabicMatcher.normalize('ءاية'), 'ايه');
      expect(ArabicMatcher.normalize('يؤمن'), 'يومن');
      expect(ArabicMatcher.normalize('مؤمنون'), 'مومنون');
      expect(ArabicMatcher.normalize('رحمة'), 'رحمه');
      expect(ArabicMatcher.normalize('هدى'), 'هدي');
      expect(ArabicMatcher.normalize('باسم الله'), 'بسم الله');
    });

    test('collapse whitespace & hapus tatweel', () {
      expect(ArabicMatcher.normalize('  بسم   الله  '), 'بسم الله');
      expect(ArabicMatcher.normalize('بسمـ الله'), 'بسم الله');
    });
  });

  group('ArabicMatcher.isCorrect', () {
    const expected = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

    test('identik tanpa harakat → benar', () {
      expect(
        ArabicMatcher.isCorrect(
          expected: expected,
          transcript: 'بسم الله الرحمن الرحيم',
        ),
        isTrue,
      );
    });

    test('transkrip dengan varian huruf (أ/ٱ/ى) → benar', () {
      expect(
        ArabicMatcher.isCorrect(
          expected: expected,
          transcript: 'باسم اللة الرحمن الرحيم',
        ),
        isTrue,
      );
    });

    test('basmalah + awal ayat sebelum ayat aktif → tetap benar', () {
      expect(
        ArabicMatcher.isCorrect(
          expected: 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
          transcript: 'بسم الله الرحمن الرحيم الحمد لله رب العالمين',
        ),
        isTrue,
      );
    });

    test('transkrip kosong → salah', () {
      expect(
        ArabicMatcher.isCorrect(expected: expected, transcript: ''),
        isFalse,
      );
    });

    test('kata hilang → salah (threshold 0.9)', () {
      // 4 dari 5 kata terbaca = 0.8 < 0.9
      expect(
        ArabicMatcher.isCorrect(
          expected: 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
          transcript: 'الحمد لله رب',
        ),
        isFalse,
      );
    });

    test('urutan kacau → salah', () {
      expect(
        ArabicMatcher.isCorrect(
          expected: 'قُلْ هُوَ ٱللَّهُ أَحَدٌ',
          transcript: 'أحد هو قل',
        ),
        isFalse,
      );
    });

    test('ayat 1 kata wajib sama persis', () {
      expect(
        ArabicMatcher.isCorrect(expected: 'قُلْ', transcript: 'قل'),
        isTrue,
      );
      expect(
        ArabicMatcher.isCorrect(expected: 'قُلْ', transcript: 'قال'),
        isFalse,
      );
    });

    test('threshold bisa diturunkan', () {
      expect(
        ArabicMatcher.isCorrect(
          expected: 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
          transcript: 'الحمد لله رب العالمين',
          threshold: 0.7,
        ),
        isTrue,
      );
    });

    test('ortografi Uthmani tanpa alif ditoleransi (jarak edit 1)', () {
      // Uthmani: العالمين (tanpa alif) — STT umum: العالمين
      expect(
        ArabicMatcher.isCorrect(
          expected: 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
          transcript: 'الحمد لله رب العالمين',
        ),
        isTrue,
      );
      // Salat dalam Uthmani: الصلوة — STT: الصلاة
      expect(
        ArabicMatcher.isCorrect(
          expected: 'وَأَقِيمُوا۟ ٱلصَّلَوٰةَ',
          transcript: 'واقموا الصلاة',
        ),
        isTrue,
      );
      // Malik dalam Uthmani: ملك (3 huruf) — STT: مالك
      expect(
        ArabicMatcher.isCorrect(
          expected: 'مَٰلِكِ يَوْمِ ٱلدِّينِ',
          transcript: 'مالك يوم الدين',
        ),
        isTrue,
      );
    });

    test('basmala di-strip untuk surah selain Al-Fatihah', () {
      // Surah 112 ayat 1: basmala + قل هو الله أحد — user cukup baca kontennya
      expect(
        ArabicMatcher.isCorrect(
          expected: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ قُلْ هُوَ ٱللَّهُ أَحَدٌ',
          transcript: 'قل هو الله أحد',
          surahNumber: 112,
        ),
        isTrue,
      );
      // Surah 1 (Al-Fatihah): basmala adalah ayat 1 tersendiri → tidak di-strip
      expect(
        ArabicMatcher.isCorrect(
          expected: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
          transcript: 'بسم الله الرحمن الرحيم',
          surahNumber: 1,
        ),
        isTrue,
      );
      // Tanpa surahNumber → basmala tidak di-strip, 4/8 kata = 0.5 < 0.9 → salah
      expect(
        ArabicMatcher.isCorrect(
          expected: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ قُلْ هُوَ ٱللَّهُ أَحَدٌ',
          transcript: 'قل هو الله أحد',
        ),
        isFalse,
      );
    });

    test('kata pendek (2 huruf) wajib sama persis', () {
      expect(
        ArabicMatcher.isCorrect(
          expected: 'قُلْ هُوَ ٱللَّهُ أَحَدٌ',
          transcript: 'قل هو الله أحد',
        ),
        isTrue,
      );
      expect(
        ArabicMatcher.isCorrect(
          expected: 'قُلْ هُوَ ٱللَّهُ أَحَدٌ',
          transcript: 'قال هو الله أحد',
        ),
        isFalse,
      );
    });
  });
}
