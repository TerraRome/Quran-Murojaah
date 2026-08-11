# Quran Rendering Rules

> **Source of truth:** This document defines how Quranic text must be rendered in the application.
>
> The goal is to provide a Mushaf-like reading experience, especially for Murojaah.

---

## 1. RTL Is Mandatory

All Quran Arabic text must use:

```text
Right-to-Left (RTL)
```

Do not force Quran text into LTR layout.

The text direction must be explicitly configured.

---

## 2. Mushaf-Like Layout

Quran text should behave like a continuous Mushaf paragraph.

Preferred:

```text
قُلْ هُوَ اللَّهُ أَحَدٌ ۝١ اللَّهُ الصَّمَدُ ۝٢
لَمْ يَلِدْ وَلَمْ يُولَدْ ۝٣
```

Avoid:

```text
Ayat 1
Ayat 2
Ayat 3
```

Avoid rendering every verse as an independent card unless the product explicitly requires it.

---

## 3. Continuous Text Flow

The renderer should support:

- continuous RTL flow
- natural line wrapping
- Arabic shaping
- verse markers
- consistent typography

The end of one verse should naturally connect to the next verse.

---

## 4. Verse Marker

Verse markers must remain visually distinct.

Example:

```text
... الْمُرْسَلِينَ ۝٤
```

Do not replace Quran verse markers with generic UI numbering such as:

```text
(4)
4.
[4]
```

unless the UI has a separate accessibility or navigation representation.

---

## 5. Font

Use a Quran-compatible Arabic font.

The selected font must correctly support:

- Arabic shaping
- harakat
- Quranic marks
- verse markers
- ligatures
- glyph positioning

Potential font categories include:

- Uthmanic
- Hafs
- Madani
- Quran-specific Arabic fonts

The exact font should be validated visually before production.

---

## 6. Hidden Verse Rendering

Murojaah requires verses to be hidden before successful recitation.

The hidden state must preserve the Mushaf layout.

Do NOT simply remove the text from the paragraph if doing so causes later verses to shift.

Preferred strategies:

- transparent text
- masked text
- fixed-layout glyph area
- equivalent rendering technique

Goal:

```text
Hidden:
████████ ۝١ ████████ ۝٢

After reveal:
قُلْ هُوَ اللَّهُ أَحَدٌ ۝١ ████████ ۝٢
```

The position of verse markers should remain stable.

---

## 7. Progressive Reveal

When a verse becomes correct:

```text
HIDDEN
  ↓
REVEALING
  ↓
VISIBLE
```

Use a subtle animation.

Recommended:

- fade in
- short opacity transition
- optional highlight

Avoid:

- large movement
- bounce
- layout jumps
- distracting animations

---

## 8. Layout Stability

Revealing a verse should not unexpectedly reposition the entire page.

The renderer must be tested with:

- short verses
- long verses
- multiple lines
- small screens
- large screens
- different font sizes

---

## 9. Auto Scroll

When the active verse changes:

```text
Current Verse
     ↓
Next Verse
     ↓
Scroll into view
```

Auto-scroll must be smooth.

Do not aggressively scroll if the active verse is already visible.

---

## 10. Active Verse

The current target verse may receive a subtle visual indication.

Possible states:

```text
Previous:
VISIBLE

Current:
HIDDEN + ACTIVE

Future:
HIDDEN
```

Avoid making the active state visually dominant.

---

## 11. Responsive Layout

The renderer must work across:

- small phones
- large phones
- tablets

Do not hardcode line breaks based on one device width.

---

## 12. Font Scaling

Support configurable Quran font size.

Changing font size must not:

- break RTL
- break verse markers
- remove harakat
- cause overlapping glyphs

---

## 13. Performance

Do not rebuild the entire Quran document unnecessarily for every speech recognition event.

Speech recognition may generate frequent partial results.

UI should update only when necessary.

Recommended separation:

```text
Speech Result
    ↓
Matching
    ↓
Murojaah State
    ↓
Verse State Change
    ↓
Renderer Update
```

Not:

```text
Every microphone event
    ↓
Rebuild entire Mushaf
```

---

## 14. Accessibility

Accessibility must not alter the visual Quran layout.

Provide semantic information where possible:

- Surah name
- verse number
- current verse
- progress

Do not read hidden Quran text aloud through accessibility services if the product's privacy/UX rules require it to remain hidden.

---

## Core Principle

> **Render Quran text as a Mushaf, not as a conventional list of UI cards.**
