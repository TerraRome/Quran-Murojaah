"""
Quran Word Aligner
==================
Dynamic Programming word alignment untuk membandingkan expected Quran verse
dengan ASR transcript.

Algorithm: Wagner-Fischer edit distance di level kata (bukan karakter),
dengan cost matrix yang menghasilkan alignment path optimal.

Status per kata:
  MATCH_EXACT      -- identical raw strings
  MATCH_LIGHT      -- match setelah strip harakat/tatweel
  MATCH_AGGRESSIVE -- match setelah normalize alef/hamza variants
  SUBSTITUTION     -- kata ada di kedua sisi tapi berbeda
  DELETION         -- kata expected tidak muncul di recognized (missing)
  INSERTION        -- kata extra di recognized (tidak ada di expected)

Scoring (per kata, max 1.0):
  MATCH_EXACT      = 1.00
  MATCH_LIGHT      = 0.90  (harakat beda — tidak masalah untuk Murojaah)
  MATCH_AGGRESSIVE = 0.75  (alef/hamza beda — borderline acceptable)
  SUBSTITUTION     = 0.00
  DELETION         = 0.00  (missing word — lebih buruk dari substitusi)
  INSERTION        = 0.00  (extra word tidak menambah score)

Effective score = sum(word_scores) / (expected_word_count + insertions)
Denominator mencakup insertions sehingga repeated words menurunkan score.
Deletion tetap dihitung penuh sebagai 0 di numerator.

Decision layer (3 states: ACCEPT / RETRY / REJECT):

  REJECT conditions (checked in order, first match wins):
    R1. effective_score == 0 and expected_word_count > 0
        (empty or completely wrong)
    R2. insertion_ratio > 0.40
        (too many extra words — repeated verse)
        insertion_ratio = insertions / expected_word_count
    R3. deletion_ratio > 0.15 AND effective_score < 0.85
        (significant missing words, not just ASR omission)
        deletion_ratio = deletions / expected_word_count
    R4. sub_ratio >= 0.20 AND effective_score < 0.85
        (significant wrong words)
        sub_ratio = substitutions / expected_word_count
        NOTE: boundary 0.20 preserves Yasin 036 (2/13=0.154) as ACCEPT

  RETRY conditions (isolated issues, possibly ASR omission):
    T1. deletion_ratio > 0.0 AND deletion_ratio <= 0.15
        AND effective_score >= 0.75
        (single deletion in long verse — may be ASR drop, not user error)

  ACCEPT: effective_score >= threshold AND no REJECT/RETRY condition
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Literal

from normalizer import NormalizedWord, make_words

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

WordStatus = Literal[
    'MATCH_EXACT',
    'MATCH_LIGHT',
    'MATCH_AGGRESSIVE',
    'SUBSTITUTION',
    'DELETION',
    'INSERTION',
]

Decision = Literal['ACCEPT', 'RETRY', 'REJECT']

SCORE_TABLE: dict[WordStatus, float] = {
    'MATCH_EXACT':      1.00,
    'MATCH_LIGHT':      0.90,
    'MATCH_AGGRESSIVE': 0.75,
    'SUBSTITUTION':     0.00,
    'DELETION':         0.00,
    'INSERTION':        0.00,
}

DISPLAY_LABEL: dict[WordStatus, str] = {
    'MATCH_EXACT':      'MATCH',
    'MATCH_LIGHT':      'MATCH~',   # ~ = normalized match
    'MATCH_AGGRESSIVE': 'MATCH≈',   # ≈ = aggressive normalized
    'SUBSTITUTION':     'SUBST',
    'DELETION':         'MISS',
    'INSERTION':        'EXTRA',
}

# ---------------------------------------------------------------------------
# Decision rule thresholds (explicit, documented)
# ---------------------------------------------------------------------------

# R2: insertion_ratio > this → REJECT (repeated/extra words)
_INSERTION_RATIO_REJECT = 0.40

# R3: deletion_ratio > this AND score < _DEL_SCORE_FLOOR → REJECT
_DELETION_RATIO_REJECT  = 0.15
_DEL_SCORE_FLOOR        = 0.85

# R4: sub_ratio >= this AND score < _SUB_SCORE_FLOOR → REJECT
# 0.20 chosen to preserve Yasin 036 (2/13 = 0.154) as ACCEPT
_SUB_RATIO_REJECT       = 0.20
_SUB_SCORE_FLOOR        = 0.85

# T1: deletion_ratio in (0, _DELETION_RATIO_REJECT] AND score >= this → RETRY
_RETRY_SCORE_FLOOR      = 0.75


@dataclass
class WordAlignment:
    """Alignment result for one word position."""
    expected: str | None          # raw expected word (None for INSERTION)
    recognized: str | None        # raw recognized word (None for DELETION)
    status: WordStatus
    score: float = field(init=False)

    def __post_init__(self):
        self.score = SCORE_TABLE[self.status]

    @property
    def label(self) -> str:
        return DISPLAY_LABEL[self.status]


@dataclass
class AlignmentResult:
    """Full alignment result for one verse comparison."""
    expected_text: str
    recognized_text: str
    alignments: list[WordAlignment]

    # ------------------------------------------------------------------
    # Aggregate counts
    # ------------------------------------------------------------------

    @property
    def expected_word_count(self) -> int:
        return sum(1 for a in self.alignments if a.status != 'INSERTION')

    @property
    def matched_exact(self) -> int:
        return sum(1 for a in self.alignments if a.status == 'MATCH_EXACT')

    @property
    def matched_light(self) -> int:
        return sum(1 for a in self.alignments if a.status == 'MATCH_LIGHT')

    @property
    def matched_aggressive(self) -> int:
        return sum(1 for a in self.alignments if a.status == 'MATCH_AGGRESSIVE')

    @property
    def substitutions(self) -> int:
        return sum(1 for a in self.alignments if a.status == 'SUBSTITUTION')

    @property
    def deletions(self) -> int:
        return sum(1 for a in self.alignments if a.status == 'DELETION')

    @property
    def insertions(self) -> int:
        return sum(1 for a in self.alignments if a.status == 'INSERTION')

    # ------------------------------------------------------------------
    # Scoring
    # ------------------------------------------------------------------

    @property
    def effective_score(self) -> float:
        """
        Score = sum(word_scores) / (expected_word_count + insertions).

        Including insertions in denominator prevents repeated-word cases
        from reaching high scores:
          2 MATCH + 1 INSERTION → 2.0 / (2 + 1) = 0.667

        Deletions already score 0 in the numerator so they penalize
        via the unchanged denominator (expected_word_count).
        """
        e = self.expected_word_count
        i = self.insertions
        denom = e + i
        if denom == 0:
            return 0.0
        total = sum(a.score for a in self.alignments if a.status != 'INSERTION')
        return total / denom

    @property
    def overall_score(self) -> float:
        """Alias for effective_score. Used by formatting helpers."""
        return self.effective_score

    # ------------------------------------------------------------------
    # Decision layer
    # ------------------------------------------------------------------

    def decide(self, threshold: float) -> tuple[Decision, str]:
        """
        Return (decision, reason) using the 3-state decision layer.

        Checks hard rules first (order matters), then falls back to
        score threshold comparison.

        Priority: REJECT > RETRY > ACCEPT
        Low false-accept rate is the primary goal.
        """
        e = self.expected_word_count
        score = self.effective_score

        if e == 0:
            return 'REJECT', 'empty expected'

        # Ratios
        ins_ratio = self.insertions / e
        del_ratio = self.deletions  / e
        sub_ratio = self.substitutions / e

        # R1: completely wrong / empty
        if score == 0.0 and e > 0:
            return 'REJECT', 'score=0'

        # R2: too many insertions (repeated words)
        if ins_ratio > _INSERTION_RATIO_REJECT:
            return 'REJECT', ('insertion_ratio=%.3f > %.2f'
                              % (ins_ratio, _INSERTION_RATIO_REJECT))

        # R3: excessive deletions
        if del_ratio > _DELETION_RATIO_REJECT and score < _DEL_SCORE_FLOOR:
            return 'REJECT', ('deletion_ratio=%.3f > %.2f and score=%.4f < %.2f'
                              % (del_ratio, _DELETION_RATIO_REJECT,
                                 score, _DEL_SCORE_FLOOR))

        # R4: excessive substitutions
        if sub_ratio >= _SUB_RATIO_REJECT and score < _SUB_SCORE_FLOOR:
            return 'REJECT', ('sub_ratio=%.3f >= %.2f and score=%.4f < %.2f'
                              % (sub_ratio, _SUB_RATIO_REJECT,
                                 score, _SUB_SCORE_FLOOR))

        # Score threshold
        if score < threshold:
            return 'REJECT', ('score=%.4f < threshold=%.2f' % (score, threshold))

        # T1: isolated deletion in long verse — may be ASR omission
        if (0.0 < del_ratio <= _DELETION_RATIO_REJECT
                and score >= _RETRY_SCORE_FLOOR):
            return 'RETRY', ('isolated deletion: del_ratio=%.3f, score=%.4f'
                             % (del_ratio, score))

        return 'ACCEPT', 'score=%.4f >= threshold=%.2f' % (score, threshold)

    def decision(self, threshold: float) -> str:
        """Compatibility shim — returns decision string only."""
        d, _ = self.decide(threshold)
        return d


# ---------------------------------------------------------------------------
# DP Alignment
# ---------------------------------------------------------------------------

# Edit costs (for DP — lower = preferred path)
_COST_MATCH  = 0.0
_COST_SUBST  = 1.0
_COST_DELETE = 1.0   # expected word missing from recognized
_COST_INSERT = 0.5   # extra word in recognized (less punished in DP path
                     # but is penalized in effective_score denominator)


def _word_match_status(exp: NormalizedWord,
                       rec: NormalizedWord) -> tuple[float, WordStatus]:
    """Return (dp_cost, status) for aligning exp against rec."""
    matched, match_type = exp.matches(rec)
    if matched:
        return _COST_MATCH, match_type  # type: ignore[return-value]
    return _COST_SUBST, 'SUBSTITUTION'


def align(expected_text: str, recognized_text: str) -> AlignmentResult:
    """
    Align expected Quran verse words against ASR recognized words using DP.

    Returns an AlignmentResult with per-word alignment status.
    """
    exp_words = make_words(expected_text)
    rec_words = make_words(recognized_text)

    n = len(exp_words)
    m = len(rec_words)

    # Build cost matrix (n+1) x (m+1)
    # dp[i][j] = min cost to align exp[:i] with rec[:j]
    INF = float('inf')
    dp = [[INF] * (m + 1) for _ in range(n + 1)]
    dp[0][0] = 0.0

    # Base cases
    for i in range(1, n + 1):
        dp[i][0] = dp[i - 1][0] + _COST_DELETE
    for j in range(1, m + 1):
        dp[0][j] = dp[0][j - 1] + _COST_INSERT

    # Fill DP table
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            cost_match, _ = _word_match_status(exp_words[i - 1], rec_words[j - 1])
            dp[i][j] = min(
                dp[i - 1][j - 1] + cost_match,
                dp[i - 1][j]     + _COST_DELETE,
                dp[i][j - 1]     + _COST_INSERT,
            )

    # Traceback
    alignments: list[WordAlignment] = []
    i, j = n, m
    while i > 0 or j > 0:
        if i > 0 and j > 0:
            cost_subst, status = _word_match_status(exp_words[i - 1],
                                                     rec_words[j - 1])
            came_from_diag = dp[i][j] == dp[i - 1][j - 1] + cost_subst
            came_from_up   = dp[i][j] == dp[i - 1][j]     + _COST_DELETE
            # came_from_left is the fallback

            if came_from_diag:
                alignments.append(WordAlignment(
                    expected=exp_words[i - 1].raw,
                    recognized=rec_words[j - 1].raw,
                    status=status,
                ))
                i -= 1
                j -= 1
            elif came_from_up:
                alignments.append(WordAlignment(
                    expected=exp_words[i - 1].raw,
                    recognized=None,
                    status='DELETION',
                ))
                i -= 1
            else:
                alignments.append(WordAlignment(
                    expected=None,
                    recognized=rec_words[j - 1].raw,
                    status='INSERTION',
                ))
                j -= 1
        elif i > 0:
            alignments.append(WordAlignment(
                expected=exp_words[i - 1].raw,
                recognized=None,
                status='DELETION',
            ))
            i -= 1
        else:
            alignments.append(WordAlignment(
                expected=None,
                recognized=rec_words[j - 1].raw,
                status='INSERTION',
            ))
            j -= 1

    alignments.reverse()

    return AlignmentResult(
        expected_text=expected_text,
        recognized_text=recognized_text,
        alignments=alignments,
    )


# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------

def format_alignment_table(result: AlignmentResult) -> str:
    """Return a formatted word-by-word alignment table."""
    lines = []
    header = '%-30s %-30s %-14s %s' % ('Expected', 'Recognized', 'Status', 'Score')
    lines.append(header)
    lines.append('-' * len(header))
    for a in result.alignments:
        exp_col = a.expected or '\u2014'
        rec_col = a.recognized or '\u2014'
        lines.append('%-30s %-30s %-14s %.2f' % (exp_col, rec_col, a.label, a.score))
    lines.append('-' * len(header))
    lines.append(
        '%-30s %.4f   (%dE + %dL + %dA / %d exp + %d ins)'
        % ('EffScore:',
           result.effective_score,
           result.matched_exact,
           result.matched_light,
           result.matched_aggressive,
           result.expected_word_count,
           result.insertions)
    )
    return '\n'.join(lines)


def format_threshold_table(result: AlignmentResult,
                           thresholds: list[float]) -> str:
    """Return a threshold decision table for a result."""
    lines = ['  EffScore: %.4f' % result.effective_score]
    lines.append('  Counts: E=%d S=%d D=%d I=%d  sub_r=%.3f del_r=%.3f ins_r=%.3f'
                 % (result.expected_word_count,
                    result.substitutions,
                    result.deletions,
                    result.insertions,
                    result.substitutions / result.expected_word_count if result.expected_word_count else 0,
                    result.deletions     / result.expected_word_count if result.expected_word_count else 0,
                    result.insertions    / result.expected_word_count if result.expected_word_count else 0))
    for t in thresholds:
        d, reason = result.decide(t)
        marker = ' \u2190' if d == 'ACCEPT' else (' ~' if d == 'RETRY' else '')
        lines.append('  t=%.2f: %-6s  [%s]%s' % (t, d, reason, marker))
    return '\n'.join(lines)
