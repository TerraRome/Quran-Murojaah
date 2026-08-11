/// MurojaahMatcher — public facade for the Quran matching engine.
///
/// Port of docs/quran/murojaah/poc/matching.py decision layer.
///
/// Usage:
///   final result = MurojaahMatcher.match(
///     expected:   verse.arabic,
///     recognized: asrTranscript,
///   );
///   switch (result.decision) {
///     case MurojaahDecision.accept: ...
///     case MurojaahDecision.retry:  ...
///     case MurojaahDecision.reject: ...
///   }
///
/// This class is a thin, stateless facade. It delegates to:
///   [WordAligner.align]                → alignment + scoring
///   [MurojaahMatchResult.fromAlignment] → decision layer
///
/// No ASR, no microphone, no UI, no state management.

import 'package:flutter/foundation.dart';

import 'word_aligner.dart';
import 'murojaah_match_result.dart';
import 'quran_normalizer.dart';

export 'murojaah_match_result.dart' show MurojaahDecision, MurojaahMatchResult;

class MurojaahMatcher {
  const MurojaahMatcher._();

  /// Primary threshold validated by the Python POC (12/12 true accept,
  /// 0/9 false accept at this value).
  static const double defaultThreshold = 0.80;

  /// Match [expected] Quran verse text against [recognized] ASR transcript.
  ///
  /// [threshold] defaults to [defaultThreshold] (0.80).
  ///
  /// E3: Before alignment, [recognized] is passed through
  /// [QuranNormalizer.resegmentFusedWords] to re-insert word boundaries that
  /// the ONNX decoder may have dropped (e.g. "اللَّهَُحَدٌ" → "اللَّهُ أَحَدٌ").
  /// Only tokens that exactly match two consecutive expected base-letter words
  /// are split — genuinely incorrect transcripts are not affected.
  ///
  /// Returns a [MurojaahMatchResult] containing the [MurojaahDecision],
  /// effective score, word counts, and per-word alignment details.
  static MurojaahMatchResult match(
    String expected,
    String recognized, {
    double threshold = defaultThreshold,
  }) {
    // E3: Re-segment fused words before alignment.
    final resegmented = QuranNormalizer.resegmentFusedWords(recognized, expected);
    if (resegmented != recognized) {
      debugPrint('[Matcher] E3 resegment: "$recognized" → "$resegmented"');
    }
    final alignment = WordAligner.align(expected, resegmented);
    return MurojaahMatchResult.fromAlignment(alignment, threshold);
  }
}
