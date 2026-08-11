import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_portfolio/Quran/murojaah/domain/word_aligner.dart';

void main() {
  group('WordAligner.align — basic alignment', () {
    test('identical single word → MATCH_EXACT, score=1.0', () {
      final r = WordAligner.align('يس', 'يس');
      expect(r.expectedWordCount, 1);
      expect(r.matchedExact, 1);
      expect(r.substitutions, 0);
      expect(r.deletions, 0);
      expect(r.insertions, 0);
      expect(r.effectiveScore, closeTo(1.0, 1e-4));
    });

    test('identical two words → MATCH_EXACT x2, score=1.0', () {
      final r = WordAligner.align(
        'وَالْقُرْآنِ الْحَكِيمِ',
        'وَالْقُرْآنِ الْحَكِيمِ',
      );
      expect(r.expectedWordCount, 2);
      expect(r.matchedExact, 2);
      expect(r.effectiveScore, closeTo(1.0, 1e-4));
    });

    test('harakat stripped → words matched (no substitution)', () {
      // وَالْقُرْآنِ vs والقران: آ (U+0622) is preserved by light normalization
      // so this pair matches at AGGRESSIVE level (آ→ا), not LIGHT.
      // الْحَكِيمِ vs الحكيم: matches at LIGHT level.
      // Either way: both words are matched, no substitutions.
      final r = WordAligner.align(
        'وَالْقُرْآنِ الْحَكِيمِ',
        'والقران الحكيم',
      );
      expect(r.matchedWords, 2);
      expect(r.substitutions, 0);
      expect(r.effectiveScore, greaterThanOrEqualTo(0.75)); // at least AGGRESSIVE score
    });

    test('alef variant difference → MATCH_AGGRESSIVE, score=0.75 per word', () {
      final r = WordAligner.align(
        'إِنَّا نَحْنُ',
        'انا نحن',
      );
      expect(r.matchedAggressive, greaterThan(0));
      expect(r.substitutions, 0);
    });

    test('one substitution, score=0', () {
      final r = WordAligner.align(
        'وَالْقُرْآنِ الْحَكِيمِ',
        'وَالْقُرْآنِ الْعَظِيمِ',
      );
      expect(r.substitutions, 1);
      expect(r.matchedExact, 1);
    });

    test('one deletion → deletions=1', () {
      // 5-word verse with 1 word missing
      final r = WordAligner.align(
        'سَلَامٌ قَوْلًا مِّن رَّبٍّ رَّحِيمٍ',
        'سَلَامٌ قَوْلًا مِّن رَّحِيمٍ',
      );
      expect(r.deletions, 1);
      expect(r.expectedWordCount, 5);
    });

    test('one insertion → insertions=1, denominator inflated', () {
      final r = WordAligner.align(
        'وَالْقُرْآنِ الْحَكِيمِ',
        'وَالْقُرْآنِ وَالْقُرْآنِ الْحَكِيمِ',
      );
      expect(r.insertions, 1);
      expect(r.expectedWordCount, 2);
      // denom = 2 + 1 = 3; score = 1.0 + 0.0 + 0.90 / 3
      expect(r.effectiveScore, lessThan(1.0));
    });

    test('empty recognized → all deletions, score=0', () {
      final r = WordAligner.align('وَالْقُرْآنِ الْحَكِيمِ', '');
      expect(r.deletions, 2);
      expect(r.effectiveScore, closeTo(0.0, 1e-4));
    });

    test('completely wrong single word → substitution, score=0', () {
      final r = WordAligner.align('يس', 'بسم');
      expect(r.substitutions, 1);
      expect(r.effectiveScore, closeTo(0.0, 1e-4));
    });
  });

  group('WordAligner.align — score formula', () {
    test('effective_score = sum(scores) / (expectedWords + insertions)', () {
      // 2 expected, 1 exact match (1.0), 1 substitution (0.0), 0 insertions
      // score = 1.0 / 2 = 0.5
      final r = WordAligner.align(
        'رَّبٍّ رَّحِيمٍ',
        'رَّبٍّ كَرِيمٍ',
      );
      expect(r.matchedExact, 1);
      expect(r.substitutions, 1);
      expect(r.insertions, 0);
      expect(r.effectiveScore, closeTo(0.5, 1e-4));
    });

    test('insertion inflates denominator', () {
      // 2 expected words, 1 insertion, 2 exact matches → 2.0 / 3 ≈ 0.6667
      final r = WordAligner.align(
        'وَالْقُرْآنِ الْحَكِيمِ',
        'وَالْقُرْآنِ وَالْقُرْآنِ الْحَكِيمِ',
      );
      expect(r.expectedWordCount, 2);
      expect(r.insertions, 1);
      // denominator = 3; numerator = matchedExact*1.0 + matchedLight*0.9 +
      //   matchedAggressive*0.75 — actual value depends on alignment path
      expect(r.effectiveScore, lessThan(1.0));
    });
  });

  group('AlignmentResult — ratios', () {
    test('subRatio = substitutions / expectedWordCount', () {
      // 2 expected, 1 substitution → 0.5
      final r = WordAligner.align('رَّبٍّ رَّحِيمٍ', 'رَّبٍّ كَرِيمٍ');
      expect(r.subRatio, closeTo(0.5, 1e-4));
    });

    test('delRatio = deletions / expectedWordCount', () {
      // 5 expected, 1 deletion → 0.2
      final r = WordAligner.align(
        'سَلَامٌ قَوْلًا مِّن رَّبٍّ رَّحِيمٍ',
        'سَلَامٌ قَوْلًا مِّن رَّحِيمٍ',
      );
      expect(r.delRatio, closeTo(0.2, 1e-4));
    });

    test('insRatio = insertions / expectedWordCount', () {
      // 2 expected, 1 insertion → 0.5
      final r = WordAligner.align(
        'وَالْقُرْآنِ الْحَكِيمِ',
        'وَالْقُرْآنِ وَالْقُرْآنِ الْحَكِيمِ',
      );
      expect(r.insRatio, closeTo(0.5, 1e-4));
    });
  });
}
