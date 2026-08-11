/// MurojaahMatchResult — value object holding the full result of one match.
///
/// Mirrors Python AlignmentResult + decide() combined into a single
/// immutable return value from [MurojaahMatcher.match].

import 'word_aligner.dart';

// ---------------------------------------------------------------------------
// MurojaahDecision enum
// ---------------------------------------------------------------------------

/// 3-state decision for a Murojaah verse recitation attempt.
///
/// Maps directly to Python Decision = Literal['ACCEPT', 'RETRY', 'REJECT'].
enum MurojaahDecision {
  /// Recitation accepted — score >= threshold, no hard rule triggered.
  accept,

  /// Isolated issue detected (e.g. single missing word in a long verse).
  /// User may retry; not counted as a false accept.
  retry,

  /// Recitation rejected — hard rule triggered or score < threshold.
  reject,
}

// ---------------------------------------------------------------------------
// MurojaahMatchResult
// ---------------------------------------------------------------------------

/// Immutable result object returned by [MurojaahMatcher.match].
///
/// Contains:
/// - [decision]       — ACCEPT / RETRY / REJECT
/// - [effectiveScore] — 0.0–1.0 (see [WordAligner] for formula)
/// - Word-level counts: [matchedWords], [substitutions], [deletions], [insertions]
/// - [reason]         — human-readable explanation of the decision
/// - [alignments]     — full per-word alignment list (for diagnostics/UI)
class MurojaahMatchResult {
  const MurojaahMatchResult({
    required this.decision,
    required this.effectiveScore,
    required this.expectedWordCount,
    required this.matchedWords,
    required this.matchedExact,
    required this.matchedLight,
    required this.matchedAggressive,
    required this.substitutions,
    required this.deletions,
    required this.insertions,
    required this.reason,
    required this.alignments,
  });

  /// Final 3-state decision.
  final MurojaahDecision decision;

  /// Effective score in [0.0, 1.0].
  final double effectiveScore;

  /// Number of expected words in the verse.
  final int expectedWordCount;

  /// Total matched words (exact + light + aggressive).
  final int matchedWords;

  /// Words matched at exact level (raw strings identical).
  final int matchedExact;

  /// Words matched at light level (harakat stripped).
  final int matchedLight;

  /// Words matched at aggressive level (alef/hamza normalized).
  final int matchedAggressive;

  /// Words that were substituted (wrong word recognized).
  final int substitutions;

  /// Words that were deleted (expected word absent from recognized).
  final int deletions;

  /// Extra words in recognized not present in expected.
  final int insertions;

  /// Human-readable explanation of the decision.
  final String reason;

  /// Per-word alignment details (for diagnostics/UI).
  final List<WordAlignment> alignments;

  // ---------------------------------------------------------------------------
  // Factory: build from an AlignmentResult + threshold
  // ---------------------------------------------------------------------------

  /// Build a [MurojaahMatchResult] from a raw [AlignmentResult] at [threshold].
  factory MurojaahMatchResult.fromAlignment(
    AlignmentResult result,
    double threshold,
  ) {
    final (decision, reason) = _decide(result, threshold);
    return MurojaahMatchResult(
      decision:           decision,
      effectiveScore:     result.effectiveScore,
      expectedWordCount:  result.expectedWordCount,
      matchedWords:       result.matchedWords,
      matchedExact:       result.matchedExact,
      matchedLight:       result.matchedLight,
      matchedAggressive:  result.matchedAggressive,
      substitutions:      result.substitutions,
      deletions:          result.deletions,
      insertions:         result.insertions,
      reason:             reason,
      alignments:         result.alignments,
    );
  }

  @override
  String toString() =>
      'MurojaahMatchResult(decision=$decision, score=${effectiveScore.toStringAsFixed(4)}, '
      'E=$expectedWordCount S=$substitutions D=$deletions I=$insertions)';
}

// ---------------------------------------------------------------------------
// Decision logic — exact port of Python AlignmentResult.decide()
// ---------------------------------------------------------------------------
//
// Hard rule thresholds (identical to Python constants):
//
//   R2: insertion_ratio > 0.40          → REJECT  (repeated/extra words)
//   R3: deletion_ratio > 0.15
//       AND effective_score < 0.85      → REJECT  (significant missing words)
//   R4: sub_ratio >= 0.20
//       AND effective_score < 0.85      → REJECT  (significant wrong words)
//       NOTE: 0.20 preserves Yasin 036 (2/13 = 0.154) as ACCEPT
//
//   T1: 0 < del_ratio <= 0.15
//       AND effective_score >= 0.75     → RETRY   (isolated ASR omission)
//
// Rule check order: R1 → R2 → R3 → R4 → score threshold → T1 → ACCEPT

const double _insertionRatioReject = 0.40;
const double _deletionRatioReject  = 0.15;
const double _delScoreFloor        = 0.85;
const double _subRatioReject       = 0.20;
const double _subScoreFloor        = 0.85;
const double _retryScoreFloor      = 0.75;

(MurojaahDecision, String) _decide(AlignmentResult result, double threshold) {
  final score    = result.effectiveScore;
  final subRatio = result.subRatio;
  final delRatio = result.delRatio;
  final insRatio = result.insRatio;

  // R1: completely wrong or empty
  if (score == 0.0 && result.expectedWordCount > 0) {
    return (MurojaahDecision.reject, 'score=0 — empty or completely wrong');
  }

  // R2: too many insertions (repeated words)
  if (insRatio > _insertionRatioReject) {
    return (
      MurojaahDecision.reject,
      'insertion_ratio=${insRatio.toStringAsFixed(3)} > $_insertionRatioReject',
    );
  }

  // R3: significant deletions
  if (delRatio > _deletionRatioReject && score < _delScoreFloor) {
    return (
      MurojaahDecision.reject,
      'del_ratio=${delRatio.toStringAsFixed(3)} > $_deletionRatioReject '
      'and score=${score.toStringAsFixed(4)} < $_delScoreFloor',
    );
  }

  // R4: significant substitutions
  if (subRatio >= _subRatioReject && score < _subScoreFloor) {
    return (
      MurojaahDecision.reject,
      'sub_ratio=${subRatio.toStringAsFixed(3)} >= $_subRatioReject '
      'and score=${score.toStringAsFixed(4)} < $_subScoreFloor',
    );
  }

  // Score threshold
  if (score < threshold) {
    return (
      MurojaahDecision.reject,
      'score=${score.toStringAsFixed(4)} < threshold=$threshold',
    );
  }

  // T1: isolated deletion — may be ASR omission
  if (delRatio > 0.0 && delRatio <= _deletionRatioReject && score >= _retryScoreFloor) {
    return (
      MurojaahDecision.retry,
      'isolated deletion: del_ratio=${delRatio.toStringAsFixed(3)}, '
      'score=${score.toStringAsFixed(4)}',
    );
  }

  return (
    MurojaahDecision.accept,
    'score=${score.toStringAsFixed(4)} >= threshold=$threshold',
  );
}
