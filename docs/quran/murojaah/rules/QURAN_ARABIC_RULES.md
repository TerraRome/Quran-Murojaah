# Quran Arabic Rules

> **Source of truth:** This document defines how Quranic Arabic text must be handled throughout the application.
>
> Quranic Arabic text is sacred source data. Never modify, generate, or reconstruct Quran text using an LLM.

---

## 1. Source of Truth

The original verified Quran Arabic text is the only source of truth for Quran display.

Use a verified Quran dataset.

Never:

- generate Quran verses with AI
- reconstruct missing Quran text
- "fix" Quran text manually
- paraphrase Quran text
- replace Quran characters with approximations
- remove Quranic characters from the stored source text

If the source data appears incorrect, investigate the dataset instead of modifying it manually.

---

## 2. Original vs Normalized Text

Maintain a strict separation between:

### Original Quran Text

Used for:

- UI rendering
- Mushaf display
- accessibility
- exporting
- copying

Example:

```text
إِنَّكَ لَمِنَ الْمُرْسَلِينَ
```

This value must remain unchanged.

### Normalized Text

Used only for:

- search
- matching
- speech recognition
- comparison

Example:

```text
انك لمن المرسلين
```

Normalized text must NEVER replace the original Quran text in the UI.

---

## 3. Unicode

Quranic Arabic must be handled as Unicode.

Do not:

- manually manipulate UTF-16 code units
- assume one Arabic character equals one code point
- remove characters blindly
- use ASCII-only string operations

Normalization must be Unicode-aware.

---

## 4. Harakat

Original Quran text must preserve all available harakat and Quranic marks.

Examples:

- Fatha
- Kasra
- Damma
- Sukun
- Shadda
- Tanwin
- Madd-related marks
- Quranic annotation marks

For matching, these marks may be removed by a dedicated normalization layer.

Example:

```text
Original:
إِنَّكَ

Matching:
انك
```

The original value must remain untouched.

---

## 5. Arabic Letter Normalization

Only the matching representation may normalize Arabic characters.

Potential normalization examples:

```text
أ → ا
إ → ا
آ → ا
ٱ → ا
```

Do this only when appropriate for the matching algorithm.

Never apply these transformations to the display/source text.

---

## 6. Quranic Marks

Quranic annotation marks may be handled differently from normal Arabic characters.

Do not blindly remove every character outside the Arabic alphabet.

The normalization pipeline must explicitly define which marks are:

- display-only
- pronunciation-related
- matching-irrelevant
- semantically relevant

---

## 7. Verse Numbers

Verse numbers are part of the Quran presentation layer.

Do not mix verse numbers into the spoken text matching input.

Example:

```text
إِنَّكَ لَمِنَ الْمُرْسَلِينَ ۝٤
```

The matching target is:

```text
إِنَّكَ لَمِنَ الْمُرْسَلِينَ
```

Not:

```text
إِنَّكَ لَمِنَ الْمُرْسَلِينَ ۝٤
```

---

## 8. Waqf and Reading Context

The system must distinguish between:

- written Quran text
- continuous recitation
- waqf/stop behavior
- wasl/connected reading

Do not assume that written final harakat always represent the exact audible form when the user stops at the verse.

This becomes especially important for advanced pronunciation validation.

---

## 9. Arabic Comparison

Do not use raw:

```dart
expected == recognized
```

for Quran recitation validation.

Use:

```text
Original Quran
      ↓
Arabic Normalizer
      ↓
Canonical Representation
      ↓
Matching Engine
```

---

## 10. Arabic and Transliteration

Arabic remains the primary representation.

Recommended model:

```dart
class QuranVerse {
  final int surahNumber;
  final int verseNumber;

  final String arabic;
  final String transliteration;
  final String normalizedArabic;
  final String normalizedTransliteration;
}
```

---

## 11. Language Integrity

Do not mix:

- Arabic source text
- Indonesian translation
- English translation
- transliteration

inside the same matching representation.

Each representation must have a clearly defined purpose.

---

## 12. Testing

Every Arabic normalization function must have tests.

Test:

- harakat removal
- Alef variants
- Quranic Alef
- Shadda
- Sukun
- Tanwin
- verse markers
- punctuation
- whitespace
- Unicode edge cases

Example:

```text
Original:
إِنَّكَ لَمِنَ الْمُرْسَلِينَ

Normalized:
انك لمن المرسلين
```

---

## Core Principle

> **Never modify the Quran source text. Normalize only a derived copy for machine processing.**
