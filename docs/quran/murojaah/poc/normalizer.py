"""
Quran Text Normalizer
=====================
Normalisasi konservatif untuk teks Arab Quran.

Tujuan: mencegah perbedaan ortografi/diakritik yang tidak signifikan
menyebabkan penolakan matching.

Prinsip:
- TIDAK menghapus huruf Arab yang bermakna.
- TIDAK mengubah makna teks.
- TIDAK menerapkan normalisasi Arab generik secara membabi-buta.
- Teks raw dan normalized selalu disimpan terpisah.

Dua level normalisasi:
  normalize_light(text)      -- hanya strip harakat + tatweel (conservative)
  normalize_aggressive(text) -- tambah normalize alef variants + hamza
"""

import re
import unicodedata

# ---------------------------------------------------------------------------
# Unicode ranges
# ---------------------------------------------------------------------------

# Arabic harakat (tashkeel): fathah, dammah, kasrah, sukun, shadda,
# tanwin variants, superscript alef, dll.
# U+064B..U+065F  (standard harakat block)
# U+0610..U+061A  (Arabic sign block: maddah above, hamzah above, etc.)
# U+06D6..U+06DC  (Quran-specific annotations)
# U+06DF..U+06E8  (Quran annotations continued)
# U+06EA..U+06EF  (Quran annotations continued)
HARAKAT_PATTERN = re.compile(
    r'[\u0610-\u061A'   # Arabic sign block
    r'\u064B-\u065F'    # Standard harakat
    r'\u0670'           # Superscript alef (ىٰ)
    r'\u06D6-\u06DC'    # Quran-specific
    r'\u06DF-\u06E8'    # Quran-specific continued
    r'\u06EA-\u06EF'    # Quran-specific continued
    r']'
)

# Tatweel (kashida, U+0640)
TATWEEL = '\u0640'

# Alef variants → plain alef ا (U+0627)
ALEF_VARIANTS = {
    '\u0622': '\u0627',  # آ → ا (alef with maddah above)
    '\u0623': '\u0627',  # أ → ا (alef with hamza above)
    '\u0625': '\u0627',  # إ → ا (alef with hamza below)
    '\u0671': '\u0627',  # ٱ → ا (alef wasla)
}

# Hamza variants → plain ء (U+0621)
HAMZA_VARIANTS = {
    '\u0624': '\u0648',  # ؤ → و (waw with hamza — keep as waw for consonant preservation)
    '\u0626': '\u064A',  # ئ → ي (ya with hamza — keep as ya)
}

# Alef maqsura ى (U+0649) — identical pronunciation to ya in some positions
# We do NOT normalize this because it changes the letter identity.

# ---------------------------------------------------------------------------
# Core normalization functions
# ---------------------------------------------------------------------------

def _strip_harakat(text: str) -> str:
    """Remove all harakat/tashkeel. Preserves all Arabic consonants."""
    return HARAKAT_PATTERN.sub('', text)


def _strip_tatweel(text: str) -> str:
    """Remove tatweel (kashida extension character)."""
    return text.replace(TATWEEL, '')


def _normalize_whitespace(text: str) -> str:
    """Collapse multiple spaces, strip leading/trailing."""
    return re.sub(r'\s+', ' ', text).strip()


def normalize_light(text: str) -> str:
    """
    Conservative normalization:
    - Strip harakat (tashkeel)
    - Strip tatweel
    - Normalize whitespace

    Safe for matching without altering letter identity.
    This is the PRIMARY normalization level used for matching.
    """
    t = _strip_harakat(text)
    t = _strip_tatweel(t)
    t = _normalize_whitespace(t)
    return t


def normalize_aggressive(text: str) -> str:
    """
    Aggressive normalization (adds on top of light):
    - All light normalizations
    - Alef variants (آ أ إ ٱ) → ا
    - Hamza variants (ؤ ئ) → base letter (و ي)

    Use only as fallback when light normalization fails to match.
    Higher false-positive risk.
    """
    t = normalize_light(text)
    for variant, base in ALEF_VARIANTS.items():
        t = t.replace(variant, base)
    for variant, base in HAMZA_VARIANTS.items():
        t = t.replace(variant, base)
    return t


# ---------------------------------------------------------------------------
# Tokenization
# ---------------------------------------------------------------------------

def tokenize(text: str) -> list[str]:
    """
    Split Arabic text into words by whitespace.
    Preserves word order (critical for Quran matching).
    Filters empty tokens.
    """
    return [w for w in text.split() if w]


# ---------------------------------------------------------------------------
# NormalizedWord: carries raw + normalized form together
# ---------------------------------------------------------------------------

class NormalizedWord:
    """A single word with its raw, light-normalized, and aggressive-normalized forms."""

    def __init__(self, raw: str):
        self.raw = raw
        self.light = normalize_light(raw)
        self.aggressive = normalize_aggressive(raw)

    def matches(self, other: 'NormalizedWord') -> tuple[bool, str]:
        """
        Compare two words. Returns (matched: bool, match_type: str).

        match_type:
          MATCH_EXACT      -- identical raw strings
          MATCH_LIGHT      -- match after light normalization (harakat stripped)
          MATCH_AGGRESSIVE -- match only after aggressive normalization
          NO_MATCH         -- no match at any level
        """
        if self.raw == other.raw:
            return True, 'MATCH_EXACT'
        if self.light == other.light:
            return True, 'MATCH_LIGHT'
        if self.aggressive == other.aggressive:
            return True, 'MATCH_AGGRESSIVE'
        return False, 'NO_MATCH'

    def __repr__(self) -> str:
        return f'NormalizedWord({self.raw!r})'


def make_words(text: str) -> list[NormalizedWord]:
    """Tokenize text and wrap each word in NormalizedWord."""
    return [NormalizedWord(w) for w in tokenize(text)]


# ---------------------------------------------------------------------------
# Diagnostic utility
# ---------------------------------------------------------------------------

def normalization_diff(expected: str, recognized: str) -> None:
    """Print a diagnostic comparison of normalization levels."""
    print(f"  RAW expected:        {expected}")
    print(f"  RAW recognized:      {recognized}")
    print(f"  LIGHT expected:      {normalize_light(expected)}")
    print(f"  LIGHT recognized:    {normalize_light(recognized)}")
    print(f"  AGGR expected:       {normalize_aggressive(expected)}")
    print(f"  AGGR recognized:     {normalize_aggressive(recognized)}")
