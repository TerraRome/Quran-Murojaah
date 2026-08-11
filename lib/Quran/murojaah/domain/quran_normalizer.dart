/// Quran Text Normalizer
/// =====================
/// Port of docs/quran/murojaah/poc/normalizer.py
///
/// Conservative normalization for Quran Arabic text.
/// The goal is to prevent insignificant orthographic/diacritic differences
/// from causing matching failures.
///
/// Principles (same as Python POC):
/// - Do NOT remove meaningful Arabic letters.
/// - Do NOT change text meaning.
/// - Always store raw and normalized forms separately.
///
/// Two normalization levels:
///   [normalizeLight]      — strip harakat + tatweel + alef wasla (ٱ→ا) only
///   [normalizeAggressive] — adds remaining alef variants + hamza normalization on top

// ---------------------------------------------------------------------------
// Unicode character ranges (mirroring Python HARAKAT_PATTERN)
// ---------------------------------------------------------------------------
//
// Arabic harakat (tashkeel):
//   U+0610–U+061A  Arabic sign block (maddah above, hamzah above, etc.)
//   U+064B–U+065F  Standard harakat (fathah, dammah, kasrah, sukun, shadda,
//                  tanwin, etc.)
//   U+0670         Superscript alef (ىٰ)
//   U+06D6–U+06DC  Quran-specific annotations
//   U+06DF–U+06E8  Quran annotations continued
//   U+06EA–U+06EF  Quran annotations continued
//
// Tatweel (kashida): U+0640
//
// Alef wasla → plain alef ا (U+0627) — applied at LIGHT level:
//   U+0671  ٱ  alef wasla (purely orthographic in Quran script; always
//              phonetically identical to plain alef — no meaning distinction)
//
// Remaining alef variants → plain alef ا (U+0627) — applied at AGGRESSIVE level:
//   U+0622  آ  alef with maddah above  (phonemically distinct — maddah)
//   U+0623  أ  alef with hamza above   (phonemically distinct — hamza)
//   U+0625  إ  alef with hamza below   (phonemically distinct — hamza)
//
// Hamza variants → base consonant:
//   U+0624  ؤ → و  (waw with hamza — preserve waw)
//   U+0626  ئ → ي  (ya with hamza — preserve ya)

class QuranNormalizer {
  const QuranNormalizer._();

  // Harakat regex — exact port of Python HARAKAT_PATTERN
  static final RegExp _harakatPattern = RegExp(
    '[\u0610-\u061A'    // Arabic sign block
    '\u064B-\u065F'     // Standard harakat
    '\u0670'            // Superscript alef
    '\u06D6-\u06DC'     // Quran-specific
    '\u06DF-\u06E8'     // Quran-specific continued
    '\u06EA-\u06EF'     // Quran-specific continued
    ']',
  );

  static const String _tatweel = '\u0640'; // kashida

  // Alef variants → ا (U+0627) — applied at AGGRESSIVE level only.
  // Note: ٱ (U+0671 alef wasla) is handled at LIGHT level (see normalizeLight).
  static const Map<String, String> _alefVariants = {
    '\u0622': '\u0627', // آ → ا  (maddah — phonemically distinct)
    '\u0623': '\u0627', // أ → ا  (hamza above — phonemically distinct)
    '\u0625': '\u0627', // إ → ا  (hamza below — phonemically distinct)
  };

  // Hamza variants → base letter
  static const Map<String, String> _hamzaVariants = {
    '\u0624': '\u0648', // ؤ → و
    '\u0626': '\u064A', // ئ → ي
  };

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Conservative normalization: strip harakat + tatweel + alef wasla → alef,
  /// then collapse whitespace.
  ///
  /// E4: ٱ (U+0671 alef wasla) is normalized to ا (U+0627) at this level.
  /// Alef wasla is purely orthographic in Uthmani Quran script — it marks where
  /// hamzat al-wasl is elided in connected speech but is phonetically identical
  /// to plain alef. ONNX ASR always outputs plain alef, so keeping U+0671 at
  /// light level causes spurious MATCH_AGGRESSIVE (score 0.75) instead of
  /// MATCH_LIGHT (score 0.90), which pushed 2-word verses below threshold 0.80.
  ///
  /// Other alef variants (أ آ إ — U+0623/0622/0625) are NOT normalized here
  /// because their hamza/maddah diacritics are phonemically meaningful.
  static String normalizeLight(String text) {
    var t = text.replaceAll(_harakatPattern, '');
    t = t.replaceAll(_tatweel, '');
    t = t.replaceAll('\u0671', '\u0627'); // ٱ (alef wasla) → ا (plain alef)
    t = _normalizeWhitespace(t);
    return t;
  }

  /// Aggressive normalization: [normalizeLight] + alef variants + hamza variants.
  ///
  /// Use only as fallback when light normalization fails to match.
  /// Higher false-positive risk than light.
  static String normalizeAggressive(String text) {
    var t = normalizeLight(text);
    for (final entry in _alefVariants.entries) {
      t = t.replaceAll(entry.key, entry.value);
    }
    for (final entry in _hamzaVariants.entries) {
      t = t.replaceAll(entry.key, entry.value);
    }
    return t;
  }

  /// Tokenize Arabic text into words (split on whitespace, filter empty).
  /// Word order is preserved — critical for Quran matching.
  static List<String> tokenize(String text) {
    return text.split(' ').where((w) => w.isNotEmpty).toList();
  }

  /// Re-segment a fused ASR transcript against a known expected verse.
  ///
  /// Problem (Milestone D device evidence):
  ///   Expected:   "اللَّهُ أَحَدٌ"   (two words)
  ///   ASR output: "اللَّهَُحَدٌ"     (fused, no space)
  ///
  ///   After harakat stripping:
  ///   Expected words: ["الله", "احد"]
  ///   ASR token:      "اللهحد"
  ///
  ///   Naive split at 4: left="الله" ✓  right="حد" ✗
  ///   The initial أ was physically dropped by the ONNX decoder during fusion.
  ///
  ///   Fix: also match split halves against the aggressively-normalised expected
  ///   set (which maps all alef variants → ا). After aggressive normalisation:
  ///   normalizeAggressive("احد") = "احد"  and  normalizeAggressive("حد") ≠ "احد"
  ///   BUT the expected set built from aggressive normalisation contains "احد",
  ///   and we match the right half "حد" by trying a one-char alef prefix restore:
  ///   prepend ا → "احد" → in expectedAggressive → SPLIT accepted.
  ///
  /// Strategy:
  ///   1. Build two lookup sets from expectedVerse:
  ///      - lightSet:      normalizeLight  per word
  ///      - aggressiveSet: normalizeAggressive per word
  ///   2. For each transcript token not in lightSet, try every split position.
  ///      Accept a split if BOTH halves match in either set, OR if the right half
  ///      with a restored leading alef (ا) matches — covering the ASR alef-drop
  ///      fusion pattern observed on device.
  ///   3. Never split blindly: both halves must match real expected words.
  ///
  /// Returns a new transcript string with spaces re-inserted.
  /// The original harakat are preserved in the output — only word boundaries
  /// are adjusted.
  static String resegmentFusedWords(String transcript, String expectedVerse) {
    if (transcript.isEmpty || expectedVerse.isEmpty) return transcript;

    // Build lookup sets at both normalization levels.
    final lightSet =
        tokenize(normalizeLight(expectedVerse)).toSet();
    final aggressiveSet =
        tokenize(normalizeAggressive(expectedVerse)).toSet();

    /// Returns true if [half] matches any expected word at light or aggressive
    /// level, or if prepending alef (ا) to [half] matches at aggressive level
    /// (covers ASR alef/hamza-drop at fusion boundary).
    bool matchesExpected(String half) {
      if (lightSet.contains(half)) return true;
      final halfAggr = normalizeAggressive(half);
      if (aggressiveSet.contains(halfAggr)) return true;
      // Alef-restore: ASR sometimes drops the initial alef/hamza when two
      // words are fused. Re-prepend plain alef and check again.
      if (aggressiveSet.contains('\u0627$halfAggr')) return true;
      return false;
    }

    final inputTokens = tokenize(transcript);
    final outputTokens = <String>[];

    for (final token in inputTokens) {
      final tokenNorm = normalizeLight(token);

      // If the token already matches an expected word (light-normalized),
      // keep it as-is — no splitting needed.
      if (lightSet.contains(tokenNorm)) {
        outputTokens.add(token);
        continue;
      }

      // Try splitting the NORMALIZED token at every position into two halves.
      // If both halves match expected words (with alef-restore fallback),
      // re-insert a space in the ORIGINAL token at the same character offset.
      bool split = false;
      for (int i = 1; i < tokenNorm.length; i++) {
        final left = tokenNorm.substring(0, i);
        final right = tokenNorm.substring(i);
        if (matchesExpected(left) && matchesExpected(right)) {
          // Map the split point back to the original (harakat-bearing) token.
          final splitOffset = _basLetterOffset(token, i);
          if (splitOffset != null) {
            final leftOrig = token.substring(0, splitOffset);
            String rightOrig = token.substring(splitOffset);

            // Alef-restore: if the right half matched only because we prepended
            // ا (i.e. the raw right half starts with a harakat or non-alef
            // consonant), prepend plain alef to the output token so the aligner
            // receives a well-formed Arabic word.
            final rightNorm = normalizeLight(rightOrig);
            final rightAggr = normalizeAggressive(rightOrig);
            final needsAlefRestore = !lightSet.contains(rightNorm) &&
                !aggressiveSet.contains(rightAggr) &&
                aggressiveSet.contains('\u0627$rightAggr');
            if (needsAlefRestore) rightOrig = '\u0627$rightOrig';

            outputTokens.add(leftOrig);
            outputTokens.add(rightOrig);
          } else {
            outputTokens.add(token);
          }
          split = true;
          break;
        }
      }

      if (!split) outputTokens.add(token);
    }

    return outputTokens.join(' ');
  }

  /// Returns the character offset in [original] after [n] base-letter
  /// (non-harakat, non-tatweel) characters have been consumed.
  ///
  /// Returns null if [original] does not contain [n] base letters.
  static int? _basLetterOffset(String original, int n) {
    int baseCount = 0;
    for (int i = 0; i < original.length; i++) {
      final ch = original[i];
      if (!_harakatPattern.hasMatch(ch) && ch != _tatweel) {
        baseCount++;
        if (baseCount == n) return i + 1;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static String _normalizeWhitespace(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

// ---------------------------------------------------------------------------
// NormalizedWord
// ---------------------------------------------------------------------------

/// Carries raw + all normalized forms of a single Arabic word.
///
/// Mirrors Python NormalizedWord — stores pre-computed light and aggressive
/// forms to avoid recomputing during DP alignment.
class NormalizedWord {
  NormalizedWord(this.raw)
      : light = QuranNormalizer.normalizeLight(raw),
        aggressive = QuranNormalizer.normalizeAggressive(raw);

  final String raw;
  final String light;
  final String aggressive;

  /// Returns (matched, matchType) comparing this (expected) against [other] (recognized).
  ///
  /// Match priority:
  ///   1. MATCH_EXACT      — raw strings identical
  ///   2. MATCH_LIGHT      — light-normalized strings identical
  ///   3. MATCH_AGGRESSIVE — aggressive-normalized strings identical
  ///   4. NO_MATCH
  (bool, String) matches(NormalizedWord other) {
    if (raw == other.raw) return (true, 'MATCH_EXACT');
    if (light == other.light) return (true, 'MATCH_LIGHT');
    if (aggressive == other.aggressive) return (true, 'MATCH_AGGRESSIVE');
    return (false, 'NO_MATCH');
  }

  /// Build a list of [NormalizedWord] from a full verse string.
  static List<NormalizedWord> makeWords(String text) {
    return QuranNormalizer.tokenize(text).map(NormalizedWord.new).toList();
  }

  @override
  String toString() => 'NormalizedWord($raw)';
}
