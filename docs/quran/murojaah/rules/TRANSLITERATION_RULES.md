# Quran Transliteration Rules

> **Purpose:** Define how Quran transliteration is stored, displayed, and normalized for Murojaah.
>
> Transliteration is a supporting representation. It is NOT the source of truth for Quran text.

---

## 1. Primary Representation

The application must prioritize:

```text
Arabic Quran
```

Transliteration is secondary.

Use transliteration for:

- speech matching
- debugging
- accessibility
- optional user assistance
- fallback recognition

---

## 2. Canonical Transliteration

Use one consistent transliteration standard throughout the application.

Do not mix standards without an explicit normalization layer.

Example:

```text
Arabic:
إِنَّكَ لَمِنَ الْمُرْسَلِينَ

Canonical:
Innaka laminal-mursalīna
```

---

## 3. Latin Diacritics

Transliteration may contain characters such as:

```text
ā
ī
ū
ṣ
ḍ
ṭ
ẓ
ḥ
ʿ
```

These characters provide additional pronunciation information.

For machine matching they may be normalized.

Example:

```text
mursalīna
```

↓

```text
mursalina
```

---

## 4. ASCII Matching Form

The application should maintain a machine-friendly normalized form.

Example:

```text
Canonical:
Innaka laminal-mursalīna

Normalized:
innaka laminal mursalina
```

Recommended transformations:

```text
lowercase
remove punctuation
normalize whitespace
normalize hyphens
normalize diacritics
```

---

## 5. Parentheses

Some transliteration datasets use:

```text
Innaka laminal-mursalīn(a)
```

The `(a)` is transliteration notation.

It is NOT an additional Quran character.

For matching:

```text
mursalīn(a)
```

must be converted to the canonical normalized representation.

Do not treat:

```text
(
)
```

as spoken tokens.

---

## 6. Hyphen

Examples:

```text
laminal-mursalīna
```

Speech recognition may output:

```text
laminal mursalina
```

or:

```text
laminalmursalina
```

The normalization layer must handle these variants.

---

## 7. Character Normalization

Recommended:

```text
ā → a
ī → i
ū → u

ṣ → s
ḍ → d
ṭ → t
ẓ → z
ḥ → h
ʿ → '
```

The exact mapping must remain configurable.

Do not use normalized Latin as the display representation for Quran text.

---

## 8. Word Boundaries

Canonical transliteration may contain different word boundaries.

Examples:

```text
laminal-mursalina
```

```text
laminal mursalina
```

```text
laminalmursalina
```

Matching should tolerate reasonable boundary variation.

---

## 9. Arabic-to-Latin Relation

Transliteration should represent the pronunciation of the Arabic text.

Do not create transliteration independently from the verified Arabic source.

Relationship:

```text
Verified Arabic
      ↓
Validated Transliteration
      ↓
Normalized Transliteration
```

---

## 10. Waqf / Wasl

Transliteration may represent reading behavior that depends on whether the reciter:

- stops
- continues

Therefore transliteration must not automatically be treated as an exact phonetic representation for every recitation context.

Advanced pronunciation validation must consider audio and phoneme alignment.

---

## 11. Speech Recognition Variants

Expected:

```text
Innaka laminal-mursalīna
```

Recognition may produce:

```text
innaka laminal mursalina
```

```text
inaka lamin almursalin
```

```text
innaka lamin al mursalina
```

The matching engine should normalize these before scoring.

---

## 12. Translation Is Not Transliteration

Do not confuse:

```text
Innaka laminal-mursalīna
```

with:

```text
Indeed, you are among the messengers.
```

The first is transliteration.

The second is translation.

Only transliteration may participate in transliteration-based matching.

---

## 13. Display

Default Murojaah UI:

```text
Arabic Quran
```

Optional:

```text
Show Transliteration
```

When enabled, transliteration should appear separately from Quran Arabic.

Do not replace Arabic with Latin by default.

---

## 14. Testing

Test normalization against:

- long vowels
- emphatic consonants
- hamzah
- ayn
- hyphens
- parentheses
- diacritics
- whitespace
- uppercase/lowercase

Example:

```text
Input:
Innaka laminal-mursalīn(a)

Output:
innaka laminal mursalina
```

---

## Core Principle

> **Transliteration is a bridge between Arabic pronunciation and machine-readable Latin text, not a replacement for Quranic Arabic.**
