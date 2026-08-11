import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_portfolio/Quran/murojaah/domain/quran_normalizer.dart';

void main() {
  group('QuranNormalizer.normalizeLight', () {
    test('removes standard harakat (fathah, dammah, kasrah, shadda, sukun)', () {
      const input = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
      final result = QuranNormalizer.normalizeLight(input);
      expect(result, 'بسم الله الرحمن الرحيم');
    });

    test('removes tatweel (kashida U+0640)', () {
      const input = 'سَلَاـمٌ'; // tatweel inserted
      final result = QuranNormalizer.normalizeLight(input);
      // harakat also stripped
      expect(result.contains('\u0640'), isFalse);
    });

    test('collapses multiple spaces and trims', () {
      const input = '  يس   وَالْقُرْآنِ  ';
      final result = QuranNormalizer.normalizeLight(input);
      // آ (U+0622) is a letter, not a diacritic — preserved by light normalization.
      // Only harakat and tatweel are stripped.
      expect(result, 'يس والقرآن');
    });

    test('preserves alef variants (light does NOT normalize alef)', () {
      const input = 'إِنَّا أَنزَلْنَاهُ'; // إ and أ present
      final result = QuranNormalizer.normalizeLight(input);
      expect(result.contains('\u0625'), isTrue); // إ preserved
      expect(result.contains('\u0623'), isTrue); // أ preserved
    });

    test('superscript alef U+0670 is removed', () {
      const input = 'الرَّحْمَٰنَ'; // ٰ = U+0670 superscript alef
      final result = QuranNormalizer.normalizeLight(input);
      expect(result.contains('\u0670'), isFalse);
    });

    test('empty string stays empty', () {
      expect(QuranNormalizer.normalizeLight(''), '');
    });

    test('plain Arabic without diacritics is unchanged', () {
      const input = 'يس';
      expect(QuranNormalizer.normalizeLight(input), 'يس');
    });
  });

  group('QuranNormalizer.normalizeAggressive', () {
    test('normalizes alef with maddah (آ → ا)', () {
      final result = QuranNormalizer.normalizeAggressive('آ');
      expect(result, '\u0627');
    });

    test('normalizes alef with hamza above (أ → ا)', () {
      final result = QuranNormalizer.normalizeAggressive('أ');
      expect(result, '\u0627');
    });

    test('normalizes alef with hamza below (إ → ا)', () {
      final result = QuranNormalizer.normalizeAggressive('إ');
      expect(result, '\u0627');
    });

    test('normalizes alef wasla (ٱ → ا)', () {
      final result = QuranNormalizer.normalizeAggressive('\u0671');
      expect(result, '\u0627');
    });

    test('normalizes waw with hamza (ؤ → و)', () {
      final result = QuranNormalizer.normalizeAggressive('ؤ');
      expect(result, '\u0648');
    });

    test('normalizes ya with hamza (ئ → ي)', () {
      final result = QuranNormalizer.normalizeAggressive('ئ');
      expect(result, '\u064A');
    });

    test('also strips harakat (aggressive is superset of light)', () {
      const input = 'إِنَّا نَحْنُ نُحْيِي الْمَوْتَىٰ';
      final result = QuranNormalizer.normalizeAggressive(input);
      expect(result, 'انا نحن نحيي الموتى');
    });
  });

  group('QuranNormalizer.tokenize', () {
    test('splits on spaces', () {
      expect(QuranNormalizer.tokenize('يس والقران'), ['يس', 'والقران']);
    });

    test('filters empty tokens from multiple spaces', () {
      expect(QuranNormalizer.tokenize('يس  والقران'), ['يس', 'والقران']);
    });

    test('empty string returns empty list', () {
      expect(QuranNormalizer.tokenize(''), isEmpty);
    });
  });

  group('NormalizedWord.matches', () {
    test('MATCH_EXACT for identical raw strings', () {
      final exp = NormalizedWord('يس');
      final rec = NormalizedWord('يس');
      final (matched, type) = exp.matches(rec);
      expect(matched, isTrue);
      expect(type, 'MATCH_EXACT');
    });

    test('MATCH_LIGHT when harakat stripped strings match', () {
      // الْحَكِيمِ vs الحكيم: harakat stripped → identical (no alef variant involved)
      final exp = NormalizedWord('الْحَكِيمِ');
      final rec = NormalizedWord('الحكيم');
      final (matched, type) = exp.matches(rec);
      expect(matched, isTrue);
      expect(type, 'MATCH_LIGHT');
    });

    test('MATCH_AGGRESSIVE when alef variant requires aggressive normalization', () {
      // وَالْقُرْآنِ vs والقران: آ (U+0622) preserved by light norm → only matches
      // at aggressive level (آ → ا)
      final exp = NormalizedWord('وَالْقُرْآنِ');
      final rec = NormalizedWord('والقران');
      final (matched, type) = exp.matches(rec);
      expect(matched, isTrue);
      expect(type, 'MATCH_AGGRESSIVE');
    });

    test('MATCH_AGGRESSIVE when alef variants normalized match', () {
      final exp = NormalizedWord('إِنَّا'); // إ → ا after aggressive
      final rec = NormalizedWord('انا');
      final (matched, type) = exp.matches(rec);
      expect(matched, isTrue);
      expect(type, 'MATCH_AGGRESSIVE');
    });

    test('NO_MATCH for completely different words', () {
      final exp = NormalizedWord('رَحِيمٍ');
      final rec = NormalizedWord('كريم');
      final (matched, _) = exp.matches(rec);
      expect(matched, isFalse);
    });
  });

  // ── E3: resegmentFusedWords ────────────────────────────────────────────────

  group('QuranNormalizer.resegmentFusedWords', () {
    // Exact device-observed failure from Milestone D (OPPO CPH2631, Android 14):
    //   Expected:   "قُلْ هُوَ ٱللَّهُ أَحَدٌ"
    //   ASR output: "قل هُوَ اللَّهَُحَدٌ"   ← "اللَّهَُحَدٌ" is a fusion of
    //               "ٱللَّهُ" + "أَحَدٌ" with dropped word boundary.
    test('E3 device regression: fused اللَّهَُحَدٌ → two tokens', () {
      const expected = 'قُلْ هُوَ ٱللَّهُ أَحَدٌ';
      const transcript = 'قل هُوَ اللَّهَُحَدٌ';
      final result = QuranNormalizer.resegmentFusedWords(transcript, expected);
      final tokens = QuranNormalizer.tokenize(result);
      expect(tokens.length, 4,
          reason: 'fused اللَّهَُحَدٌ must be split into two words');
    });

    test('unfused tokens are preserved unchanged', () {
      const expected = 'قُلْ هُوَ ٱللَّهُ أَحَدٌ';
      // All four tokens already match expected words — nothing should be split.
      const transcript = 'قل هو الله احد';
      final result = QuranNormalizer.resegmentFusedWords(transcript, expected);
      expect(QuranNormalizer.tokenize(result).length, 4);
    });

    test('completely wrong word is not split', () {
      // "خطأ" does not decompose into any two expected words — must stay as-is.
      const expected = 'قُلْ هُوَ ٱللَّهُ أَحَدٌ';
      const transcript = 'خطأ';
      final result = QuranNormalizer.resegmentFusedWords(transcript, expected);
      expect(result, transcript);
    });

    test('empty transcript returns empty string', () {
      expect(
        QuranNormalizer.resegmentFusedWords('', 'قُلْ هُوَ ٱللَّهُ أَحَدٌ'),
        '',
      );
    });

    test('empty expected returns transcript unchanged', () {
      expect(
        QuranNormalizer.resegmentFusedWords('اللهحد', ''),
        'اللهحد',
      );
    });
  });
}
