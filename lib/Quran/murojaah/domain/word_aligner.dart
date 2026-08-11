/// Quran Word Aligner
/// ==================
/// Port of docs/quran/murojaah/poc/aligner.py
///
/// Dynamic-programming word alignment comparing an expected Quran verse
/// against an ASR transcript.
///
/// Algorithm: Wagner-Fischer edit distance at word level (not character level),
/// with a cost matrix that produces the optimal alignment path.
///
/// Word status per aligned position:
///   MATCH_EXACT      — identical raw strings
///   MATCH_LIGHT      — match after harakat/tatweel strip
///   MATCH_AGGRESSIVE — match after alef/hamza normalization
///   SUBSTITUTION     — word present on both sides but different
///   DELETION         — expected word absent from recognized (missing)
///   INSERTION        — extra word in recognized (not in expected)
///
/// Scoring (per word, max 1.0):
///   MATCH_EXACT      = 1.00
///   MATCH_LIGHT      = 0.90  (harakat difference — acceptable for Murojaah)
///   MATCH_AGGRESSIVE = 0.75  (alef/hamza difference — borderline acceptable)
///   SUBSTITUTION     = 0.00
///   DELETION         = 0.00  (missing word — fully penalized)
///   INSERTION        = 0.00  (extra word adds nothing to score)
///
/// Effective score = sum(wordScores) / (expectedWordCount + insertions)
/// Insertions inflate the denominator so repeated words cannot reach 1.0.
///
/// DP edit costs (used only for path selection, not for scoring):
///   MATCH  = 0.0
///   SUBST  = 1.0
///   DELETE = 1.0   (expected word missing from recognized)
///   INSERT = 0.5   (extra word in recognized — less penalized in path selection
///                   but penalized in effectiveScore denominator)

import 'quran_normalizer.dart';

// ---------------------------------------------------------------------------
// Word status enum
// ---------------------------------------------------------------------------

enum WordStatus {
  matchExact,
  matchLight,
  matchAggressive,
  substitution,
  deletion,
  insertion,
}

extension WordStatusScore on WordStatus {
  /// Score contribution of this word status (0.0–1.0).
  double get score {
    switch (this) {
      case WordStatus.matchExact:      return 1.00;
      case WordStatus.matchLight:      return 0.90;
      case WordStatus.matchAggressive: return 0.75;
      case WordStatus.substitution:    return 0.00;
      case WordStatus.deletion:        return 0.00;
      case WordStatus.insertion:       return 0.00;
    }
  }

  /// Human-readable label for diagnostics.
  String get label {
    switch (this) {
      case WordStatus.matchExact:      return 'MATCH';
      case WordStatus.matchLight:      return 'MATCH~';
      case WordStatus.matchAggressive: return 'MATCH≈';
      case WordStatus.substitution:    return 'SUBST';
      case WordStatus.deletion:        return 'MISS';
      case WordStatus.insertion:       return 'EXTRA';
    }
  }
}

// ---------------------------------------------------------------------------
// WordAlignment: result for one word position
// ---------------------------------------------------------------------------

class WordAlignment {
  const WordAlignment({
    required this.expected,
    required this.recognized,
    required this.status,
  });

  /// Raw expected word; null for INSERTION.
  final String? expected;

  /// Raw recognized word; null for DELETION.
  final String? recognized;

  final WordStatus status;

  double get score => status.score;
  String get label => status.label;

  @override
  String toString() =>
      'WordAlignment(exp=$expected, rec=$recognized, status=${status.name}, score=$score)';
}

// ---------------------------------------------------------------------------
// DP costs
// ---------------------------------------------------------------------------

const double _costMatch  = 0.0;
const double _costSubst  = 1.0;
const double _costDelete = 1.0;
const double _costInsert = 0.5;

// ---------------------------------------------------------------------------
// Internal: classify word match type
// ---------------------------------------------------------------------------

/// Returns (dpCost, status) for aligning [exp] against [rec].
(double, WordStatus) _wordMatchStatus(NormalizedWord exp, NormalizedWord rec) {
  final (matched, matchType) = exp.matches(rec);
  if (matched) {
    final status = switch (matchType) {
      'MATCH_EXACT'      => WordStatus.matchExact,
      'MATCH_LIGHT'      => WordStatus.matchLight,
      'MATCH_AGGRESSIVE' => WordStatus.matchAggressive,
      _                  => WordStatus.matchExact, // fallback (shouldn't happen)
    };
    return (_costMatch, status);
  }
  return (_costSubst, WordStatus.substitution);
}

// ---------------------------------------------------------------------------
// WordAligner
// ---------------------------------------------------------------------------

/// Performs DP word-level alignment of a Quran verse against an ASR transcript.
///
/// This is a pure static utility — no state. Call [align] to get an
/// [AlignmentResult].
class WordAligner {
  const WordAligner._();

  /// Align [expectedText] (Quran verse) against [recognizedText] (ASR output).
  ///
  /// Returns an [AlignmentResult] with per-word alignment status, aggregate
  /// counts, effective score, and the [decide] method.
  static AlignmentResult align(String expectedText, String recognizedText) {
    final expWords = NormalizedWord.makeWords(expectedText);
    final recWords = NormalizedWord.makeWords(recognizedText);

    final n = expWords.length;
    final m = recWords.length;

    // Build DP cost table (n+1) x (m+1)
    // dp[i][j] = min cost to align expWords[:i] with recWords[:j]
    const inf = double.infinity;
    final dp = List.generate(n + 1, (_) => List.filled(m + 1, inf));
    dp[0][0] = 0.0;

    for (var i = 1; i <= n; i++) dp[i][0] = dp[i - 1][0] + _costDelete;
    for (var j = 1; j <= m; j++) dp[0][j] = dp[0][j - 1] + _costInsert;

    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final (costMatch, _) = _wordMatchStatus(expWords[i - 1], recWords[j - 1]);
        dp[i][j] = [
          dp[i - 1][j - 1] + costMatch,
          dp[i - 1][j]     + _costDelete,
          dp[i][j - 1]     + _costInsert,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    // Traceback — reconstruct alignment path
    final alignments = <WordAlignment>[];
    var i = n;
    var j = m;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0) {
        final (costSubst, status) =
            _wordMatchStatus(expWords[i - 1], recWords[j - 1]);
        final fromDiag = dp[i][j] == dp[i - 1][j - 1] + costSubst;
        final fromUp   = dp[i][j] == dp[i - 1][j]     + _costDelete;

        if (fromDiag) {
          alignments.add(WordAlignment(
            expected:   expWords[i - 1].raw,
            recognized: recWords[j - 1].raw,
            status:     status,
          ));
          i--;
          j--;
        } else if (fromUp) {
          alignments.add(WordAlignment(
            expected:   expWords[i - 1].raw,
            recognized: null,
            status:     WordStatus.deletion,
          ));
          i--;
        } else {
          alignments.add(WordAlignment(
            expected:   null,
            recognized: recWords[j - 1].raw,
            status:     WordStatus.insertion,
          ));
          j--;
        }
      } else if (i > 0) {
        alignments.add(WordAlignment(
          expected:   expWords[i - 1].raw,
          recognized: null,
          status:     WordStatus.deletion,
        ));
        i--;
      } else {
        alignments.add(WordAlignment(
          expected:   null,
          recognized: recWords[j - 1].raw,
          status:     WordStatus.insertion,
        ));
        j--;
      }
    }

    // Traceback produces reversed order — reverse to restore natural order
    return AlignmentResult(
      expectedText:   expectedText,
      recognizedText: recognizedText,
      alignments:     alignments.reversed.toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// AlignmentResult
// ---------------------------------------------------------------------------

/// Full alignment result for one verse comparison.
///
/// Mirrors Python AlignmentResult. Carries per-word alignments and provides
/// aggregated counts, effective score, and [decide].
class AlignmentResult {
  AlignmentResult({
    required this.expectedText,
    required this.recognizedText,
    required this.alignments,
  });

  final String expectedText;
  final String recognizedText;
  final List<WordAlignment> alignments;

  // ---------------------------------------------------------------------------
  // Aggregate counts (computed once, cached)
  // ---------------------------------------------------------------------------

  late final int matchedExact = _count(WordStatus.matchExact);
  late final int matchedLight = _count(WordStatus.matchLight);
  late final int matchedAggressive = _count(WordStatus.matchAggressive);
  late final int substitutions = _count(WordStatus.substitution);
  late final int deletions = _count(WordStatus.deletion);
  late final int insertions = _count(WordStatus.insertion);

  /// Total matched words (any match level).
  late final int matchedWords = matchedExact + matchedLight + matchedAggressive;

  /// Number of expected words (deletions are expected words that did not appear).
  late final int expectedWordCount = alignments
      .where((a) => a.status != WordStatus.insertion)
      .length;

  /// Effective score = sum(wordScores) / (expectedWordCount + insertions).
  ///
  /// Insertions inflate the denominator so repeated words cannot reach 1.0.
  late final double effectiveScore = () {
    final denom = expectedWordCount + insertions;
    if (denom == 0) return 0.0;
    final scoreSum = alignments.fold<double>(0.0, (s, a) => s + a.score);
    return scoreSum / denom;
  }();

  // ---------------------------------------------------------------------------
  // Ratios (used by hard rules)
  // ---------------------------------------------------------------------------

  late final double subRatio = expectedWordCount > 0
      ? substitutions / expectedWordCount
      : 0.0;

  late final double delRatio = expectedWordCount > 0
      ? deletions / expectedWordCount
      : 0.0;

  late final double insRatio = expectedWordCount > 0
      ? insertions / expectedWordCount
      : 0.0;

  // ---------------------------------------------------------------------------
  // Internal helper
  // ---------------------------------------------------------------------------

  int _count(WordStatus s) => alignments.where((a) => a.status == s).length;
}
