# Murojaah Rules

> IMPORTANT: This document is the source of truth for the Murojaah feature.
>
> Any implementation related to Murojaah MUST follow these rules.
>
> Before modifying Murojaah architecture, UI, ASR, matching,
> verse progression, or recitation validation, read this document first.
>
> Do not implement future roadmap items unless explicitly requested.
>
> Work on one milestone at a time.
>
> After completing a milestone:
>
> 1. Run tests.
> 2. Report changed files.
> 3. Report implementation status.
> 4. STOP and wait for further instructions.

# Murojaah Feature Specification & Development Roadmap

## 1. Overview

**Murojaah** adalah fitur untuk membantu pengguna mengulang hafalan Al-Qur'an dengan cara melafalkan ayat dari hafalan.

Konsep utama:

> User membaca ayat → sistem mendengarkan → sistem mengenali bacaan → jika cocok, ayat terbuka → lanjut ke ayat berikutnya.

Teks ayat pada awalnya **tidak terlihat**. User harus membaca dari hafalan.

Jika bacaan berhasil divalidasi, ayat akan muncul secara bertahap sampai seluruh surat terbuka.

Murojaah menggantikan tab **Lamp**.

---

# 2. Core UX

Flow utama:

```text
Pilih Surat
    ↓
Mulai Murojaah
    ↓
Ayat tersembunyi
    ↓
User membaca ayat 1
    ↓
Quran Speech Recognition
    ↓
Verse Matching
    ↓
Correct?
 ┌──┴───┐
YES    NO
 ↓      ↓
Reveal  Retry
 ↓
Ayat 2
 ↓
...
 ↓
Selesai
```

User **wajib membaca secara berurutan**.

Tidak boleh melompat ke ayat berikutnya.

---

# 3. Mushaf UI

## 3.1 RTL

Quran harus dirender sebagai **RTL (Right-to-Left)**.

Gunakan:

- Arabic text shaping
- Quran-compatible font
- RTL paragraph
- natural line wrapping
- Quranic verse markers

Jangan membuat UI seperti list:

```text
Ayat 1
Ayat 2
Ayat 3
```

atau:

```text
① Ayat 1
② Ayat 2
③ Ayat 3
```

Yang diinginkan adalah tampilan seperti mushaf.

Contoh:

```text
قُلْ هُوَ اللَّهُ أَحَدٌ ۝١ اللَّهُ الصَّمَدُ ۝٢
لَمْ يَلِدْ وَلَمْ يُولَدْ ۝٣ وَلَمْ يَكُن لَّهُ
كُفُوًا أَحَدٌ ۝٤
```

---

# 4. Hidden Verse

Ketika Murojaah dimulai, teks ayat disembunyikan **per kata**.

Nomor ayat tetap terlihat.

Contoh:

```text
████ ████ ████ ████ ۝١ ████ ████ ۝٢
████ ████ ████ ۝٣ ████ ████ ۝٤
```

Placeholder hanya berfungsi untuk menyembunyikan teks.

**Layout tidak boleh berubah ketika kata di-reveal.**

---

# 5. Progressive Reveal (per kata)

Reveal terjadi **kata demi kata**, bukan ayat demi ayat.

Kata yang diucapkan benar langsung terbuka (warna hijau). Kata yang salah atau
terlupa tetap tertutup dan ditandai merah.

```text
قُلْ هُوَ ████ ████ ۝١ ████ ████ ████ ۝٢
```

Kata berikutnya benar:

```text
قُلْ هُوَ اللَّهُ ████ ۝١ ████ ████ ████ ۝٢
```

Dan seterusnya sampai seluruh surah terbuka.

Aturan:

- Satu event `WordMatchedEvent` hijau = satu kata terbuka.
- Event merah = kata ditandai merah + haptic (`HapticFeedback.mediumImpact()`).
- Kata yang dilewati dicari dengan `LcsOmissionDetector` (Best-Drop LCS) dan
  ikut ditandai merah.
- Reveal harus ringan: tidak ada animasi layout, tidak menggeser baris.

Jangan menyebabkan layout mushaf bergeser secara tiba-tiba.

---

# 5a. Engine

Pelacakan bacaan memakai `package:recite_quran` (on-device, DTW word
alignment + zipformer ONNX). Konfigurasi mode ujian:

```dart
const TrackerConfig(
  enableAutoReanchor: false,   // lompatan tidak dimaafkan
  reanchorStallThreshold: 24,
)
```

`enableAutoReanchor: true` hanya untuk mode tilawah/baca santai.

---

# 5b. Peek Hint & Skor Akurasi

Tombol mata di header (`Icons.visibility_outlined`) membuka **satu kata
berikutnya** yang belum terbuka selama 2 detik, lalu menutupnya lagi.

- Kata hasil peek tampil dengan warna tinta biasa (bukan hijau) dan **tidak**
  dihitung sebagai hafal — hanya info.
- Setiap peek dihitung (`_peekCount`) dan ditampilkan di baris progres
  (`12 / 50 · 2 lihat`).
- Skor akurasi = `benar / (benar + salah)`, ditampilkan persen di baris progres.
  Belum ada percobaan → 100%.

---

# 5c. Sheet Koreksi

Ketuk kata **merah** → bottom sheet membandingkan:

- **Seharusnya** — kata dari `aya_text` (Amiri, hijau).
- **Terdengar** — `WordMatchedEvent.cleanAsr` saat kata itu ditandai merah
  (merah), atau `tidak terdengar` bila ASR tidak menghasilkan teks
  (kata terlewat hasil `LcsOmissionDetector`).

Sheet tidak mengubah state hafalan; hanya menjelaskan kesalahan.

---

# 6. Quran Text Source of Truth

**Teks Arab Al-Qur'an adalah source of truth.**

Jangan menggunakan LLM untuk:

- generate ayat
- memperbaiki ayat
- menebak ayat
- mengubah huruf
- melakukan transliterasi tanpa validasi
- mengoreksi source Quran

Gunakan **verified Quran dataset**.

---

# 7. Text Representations

Setiap ayat idealnya memiliki beberapa representation.

```text
Quran Arabic
     ↓
Canonical Transliteration
     ↓
Normalized Representation
```

Contoh:

### Arabic

```text
إِنَّكَ لَمِنَ الْمُرْسَلِينَ
```

### Transliteration

```text
Innaka laminal-mursalīna
```

### Normalized

```text
innaka laminal mursalina
```

Arabic tetap menjadi source of truth.

Transliterasi hanya menjadi bridge untuk matching/debugging/accessibility.

---

# 8. Transliteration Rules

Transliterasi harus konsisten.

Contoh:

```text
Innaka laminal-mursalīna
```

Jangan mencampurkan berbagai standar transliterasi secara sembarangan.

Karakter seperti:

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

boleh dinormalisasi untuk machine matching.

Contoh:

```text
mursalīna
```

↓

```text
mursalina
```

---

# 9. Parenthetical Transliteration

Beberapa dataset menggunakan format:

```text
Innaka laminal-mursalīn(a)
```

`(a)` bukan huruf Quran tambahan.

Ini merupakan notasi transliterasi untuk menunjukkan pembacaan/harakat akhir berdasarkan sistem transliterasi atau konteks waqaf/wasl.

Untuk matching:

```text
mursalīn(a)
```

harus dinormalisasi menjadi canonical representation.

Jangan memperlakukan `(a)` sebagai token Quran.

---

# 10. Speech Recognition Strategy

Jangan mengunci arsitektur ke satu provider.

Gunakan abstraction:

```dart
abstract class SpeechRecognitionService {
  Future<SpeechResult> recognize(...);
}
```

Implementasi dapat berupa:

```text
QuranASRService
WhisperService
CloudSpeechService
FutureQuranASRService
```

Tujuannya agar engine dapat diganti tanpa mengubah Murojaah logic.

---

# 11. Quran-Specific ASR

Prioritas model:

```text
Quran-specific ASR
        >
Arabic general ASR
        >
Generic multilingual ASR
```

Karena vocabulary bacaan Quran relatif terbatas dan pronunciation pattern-nya spesifik.

Model harus diuji berdasarkan **bacaan Quran**, bukan hanya benchmark Arabic umum.

---

# 12. Candidate ASR Architecture

Kandidat awal yang perlu dievaluasi:

### Candidate A — Quran FastConformer

Quran-specific FastConformer / NeMo-based model.

Kelebihan yang diharapkan:

- Quran-specific training
- streaming
- low latency
- suitable for continuous recitation

---

### Candidate B — Quran STT ONNX

Prioritaskan untuk POC mobile/local inference.

Target architecture:

```text
Flutter
   ↓
Microphone
   ↓
ONNX Runtime
   ↓
Quran ASR
   ↓
Transcript
```

Keuntungan:

- local inference
- offline potential
- tidak bergantung API
- dapat dievaluasi untuk mobile

---

### Candidate C — Quran Fine-tuned Whisper

Gunakan sebagai baseline.

Contoh architecture:

```text
Microphone
    ↓
Whisper Quran
    ↓
Arabic Transcript
    ↓
Normalization
    ↓
Matching
```

Whisper general juga dapat digunakan sebagai fallback benchmark.

---

# 13. Important Principle

Speech-to-text hanya menjawab:

> "Apa yang kemungkinan diucapkan user?"

Speech-to-text **belum berarti**:

> "User membaca Quran dengan tajwid dan makhraj yang benar."

Karena itu jangan menggunakan label:

```text
Bacaan Tajwid Benar
```

hanya berdasarkan ASR text matching.

Untuk MVP gunakan istilah:

```text
Bacaan cocok
```

atau:

```text
Ayat berhasil dikenali
```

---

# 14. Murojaah Matching Pipeline

```text
Microphone
    ↓
Audio Stream
    ↓
Quran ASR
    ↓
Recognition Result
    ↓
Text Normalization
    ↓
Verse Alignment
    ↓
Word Matching
    ↓
Confidence Score
    ↓
Murojaah Decision
```

---

# 15. Matching Levels

## Level 1 — Exact Match

```text
normalize(expected) == normalize(recognized)
```

---

## Level 2 — Word Match

Bandingkan setiap kata.

Contoh:

```text
قُلْ       ✅
هُوَ       ✅
اللَّهُ    ❌
أَحَدٌ     ✅
```

---

## Level 3 — Fuzzy Match

Gunakan similarity score.

Contoh initial threshold:

```text
>= 95%
    ACCEPT

85-94%
    ALMOST

< 85%
    RETRY
```

Threshold harus configurable.

Jangan hardcode di UI.

---

# 16. Sequential Validation

Misalnya:

```text
Current Verse = 3
```

Expected:

```text
Verse 3
```

Jika ASR mendeteksi Verse 4:

```text
Verse 4 != Verse 3
```

Maka:

```text
REJECT
```

Ayat 4 tidak boleh terbuka.

User tetap harus membaca ayat 3.

---

# 17. Murojaah State Machine

Gunakan state yang eksplisit.

```text
IDLE
 ↓
PREPARING
 ↓
LISTENING
 ↓
PROCESSING
 ↓
VALIDATING
 ├── CORRECT
 │      ↓
 │   REVEALING
 │      ↓
 │   NEXT_VERSE
 │
 └── INCORRECT
        ↓
      RETRY
```

Completion:

```text
LAST_VERSE
    ↓
COMPLETED
```

---

# 18. Progress

Progress dihitung dari **jumlah kata yang cocok / total kata surah**.

Contoh:

```text
Surah Al-Ikhlas

12 / 21

████████░░░░░░
```

Progress tidak boleh maju hanya karena microphone menerima suara.

Progress hanya maju ketika kata berhasil divalidasi (event hijau).

---

# 19. Feedback

## Correct

```text
✓ Kata dikenali
```

Actions:

- reveal kata (hijau)
- optional highlight
- optional haptic
- lanjut ke kata berikutnya

---

## Almost

```text
Hampir benar, silakan ulangi.
```

Kata yang salah tetap tertutup; kata sebelumnya yang sudah hijau tetap terbuka.

---

## Incorrect

```text
Bacaan belum sesuai.
Silakan ulangi kata ini.
```

Kata yang salah ditandai merah + haptic. Tombol **Ulangi** menghapus tanda
merah pada ayat aktif tanpa menutup kata yang sudah benar.

---

# 20. Advanced Pronunciation Roadmap

Setelah ASR berhasil, jangan langsung membuat Tajweed AI.

Naikkan kemampuan secara bertahap.

```text
Phase 1
Text Recognition

        ↓

Phase 2
Word Alignment

        ↓

Phase 3
Phoneme Alignment

        ↓

Phase 4
Pronunciation Analysis

        ↓

Phase 5
Tajweed Analysis

        ↓

Phase 6
Makharij Analysis
```

---

# 21. Phoneme-Level Analysis

Pada fase advanced:

```text
Audio
 ↓
Quran ASR
 ↓
Phoneme Recognition
 ↓
Expected Phoneme
 ↓
Alignment
 ↓
Pronunciation Score
```

Contoh:

```text
Expected:
ص

Detected:
س

Potential pronunciation difference
```

Jangan langsung menyimpulkan kesalahan tajwid tanpa model dan referensi yang valid.

---

# 22. Tajweed Analysis

Future feature.

Target:

- Madd
- Ghunnah
- Qalqalah
- Ikhfa
- Idgham
- Iqlab
- Izhar
- dan aturan lainnya

Arsitektur:

```text
Audio
 ↓
Phoneme Alignment
 ↓
Tajweed Feature Extraction
 ↓
Rule Evaluation
 ↓
Feedback
```

Tajweed engine harus memiliki referensi ilmu tajwid yang tervalidasi.

---

# 23. Development Roadmap

## Milestone 0 — Research & POC

**Jangan menyentuh aplikasi utama terlebih dahulu.**

Buat POC terpisah.

Target:

```text
Audio Quran
    ↓
Quran ASR
    ↓
Transcript
```

Bandingkan minimal:

- Quran FastConformer
- Quran STT ONNX
- Quran fine-tuned Whisper

Test menggunakan beberapa rekaman bacaan nyata.

### Metrics

Ukur:

- WER
- CER
- verse recognition accuracy
- word accuracy
- latency
- model size
- RAM
- CPU
- realtime capability
- offline capability

**Milestone dianggap selesai jika model terbaik sudah diketahui.**

---

# Milestone 1 — Murojaah Foundation

Fokus hanya:

- Mengganti tab Lamp menjadi Murojaah.
- Routing.
- Feature folder.
- State management.
- Murojaah screen.
- Dummy data.

Belum:

- microphone
- ASR
- AI
- fuzzy matching

Target:

```text
Murojaah screen
    ↓
working
```

---

# Milestone 2 — Mushaf Renderer

Implementasi:

- RTL
- Quran font
- Arabic shaping
- mushaf-like paragraph
- verse markers
- natural line wrapping

Tambahkan hidden/reveal system.

Untuk sementara gunakan:

```text
Reveal Verse
```

button sebagai simulasi.

Target:

```text
[Reveal Verse]
```

dapat membuka ayat berikutnya.

---

# Milestone 3 — Sequential Murojaah State

Implementasi:

- current verse
- completed verses
- sequential validation
- progress
- retry
- next verse
- auto scroll
- completion

Masih tanpa microphone.

Gunakan:

```text
[Correct]
[Incorrect]
```

sebagai simulator.

---

# Milestone 4 — Speech Recognition Integration

Integrasikan ASR yang dipilih dari Milestone 0.

Implementasi:

- microphone permission
- audio session
- audio streaming
- speech recognition
- partial result
- final result
- error state

Target:

```text
User speaks
    ↓
Transcript appears
```

Belum melakukan pronunciation scoring.

---

# Milestone 5 — Quran Matching Engine

Implementasi:

- Arabic normalization
- transliteration normalization
- word alignment
- fuzzy matching
- confidence score
- verse identification

Target:

```text
User speaks
    ↓
ASR
    ↓
Matching
    ↓
Correct / Retry
```

---

# Milestone 6 — Real Murojaah UX

Gabungkan:

```text
ASR
+
Matching
+
Sequential State
+
Mushaf Renderer
```

Flow final:

```text
User reads
    ↓
ASR
    ↓
Match
    ↓
Correct
    ↓
Reveal
    ↓
Next Verse
```

Tambahkan:

- fade reveal
- active verse indicator
- haptic
- auto scroll
- recording/listening indicator
- retry feedback

---

# Milestone 7 — Performance & Offline

Fokus:

- model loading
- memory usage
- CPU usage
- inference latency
- battery
- offline behavior
- audio lifecycle
- background/foreground handling

Target:

Murojaah dapat berjalan dengan nyaman pada device target tanpa ketergantungan internet jika model mendukung local inference.

---

# Milestone 8 — Word-Level Feedback

Jika ASR cukup akurat:

```text
قُلْ       ✓
هُوَ       ✓
اللَّهُ    ✗
أَحَدٌ     ✓
```

User dapat mengetahui bagian mana yang perlu diulang.

Jangan langsung memberikan diagnosis tajwid.

Gunakan istilah:

```text
Bagian yang belum dikenali
```

---

# Milestone 9 — Phoneme Recognition

Mulai mengevaluasi:

- phoneme alignment
- pronunciation similarity
- audio-to-phoneme matching

Target:

```text
Expected phoneme
        vs
Detected phoneme
```

---

# Milestone 10 — Tajweed & Makharij

Future advanced feature.

Implementasi:

- Tajweed detection
- Makharij detection
- pronunciation scoring
- detailed feedback

Ini merupakan **fase terpisah** dan tidak boleh menghambat MVP.

---

# 24. Development Rules

## Rule 1 — One Milestone at a Time

Jangan mengerjakan banyak milestone sekaligus.

Selesaikan:

```text
Milestone N
```

sebelum:

```text
Milestone N+1
```

---

## Rule 2 — Working State

Setiap milestone harus menghasilkan aplikasi yang masih dapat:

- build
- run
- test

---

## Rule 3 — Stop After Milestone

Setelah milestone selesai:

1. Jelaskan perubahan.
2. Jelaskan file yang dibuat/diubah.
3. Jalankan test.
4. Laporkan hasil.
5. **STOP.**

Jangan otomatis melanjutkan milestone berikutnya.

Tunggu instruksi berikutnya.

---

# 25. Avoid Premature Complexity

Jangan langsung menambahkan:

- Tajweed AI
- phoneme analysis
- cloud backend
- analytics
- social features
- multiplayer
- complex scoring

sebelum core Murojaah bekerja.

Prioritas:

```text
Mushaf UI
   ↓
Sequential Reveal
   ↓
ASR
   ↓
Matching
   ↓
Working Murojaah
```

---

# 26. Testing Strategy

Setiap layer harus dapat dites secara terpisah.

## Quran Renderer

Test:

- RTL
- line wrapping
- verse marker
- hidden verse
- reveal

## Normalizer

Test:

```text
Arabic → normalized
Latin → normalized
```

## Matching

Test:

```text
exact
near match
wrong verse
partial
empty
```

## Murojaah State

Test:

```text
verse 1 → verse 2 → verse 3
```

dan:

```text
verse 1 → verse 3
```

harus ditolak.

## ASR

Benchmark dengan audio nyata.

---

# 27. Recommended Architecture

```text
features/
└── murojaah/
    ├── data/
    │   ├── datasources/
    │   ├── models/
    │   └── repositories/
    │
    ├── domain/
    │   ├── entities/
    │   ├── repositories/
    │   └── usecases/
    │
    └── presentation/
        ├── bloc/
        ├── pages/
        ├── widgets/
        └── components/
```

ASR abstraction:

```text
domain/
└── services/
    └── speech_recognition_service.dart
```

Implementation:

```text
data/
└── services/
    ├── quran_asr_service.dart
    ├── whisper_asr_service.dart
    └── onnx_quran_asr_service.dart
```

---

# 28. Important Separation

Pisahkan:

```text
Quran Data
```

dari:

```text
ASR
```

dan:

```text
Matching
```

dan:

```text
UI
```

Jangan membuat:

```text
MurojaahPage
    ↓
Microphone
    ↓
ASR
    ↓
Normalization
    ↓
Matching
```

semuanya dalam satu widget.

---

# 29. Final Architecture

Target jangka panjang:

```text
                    Quran Dataset
                         │
                         ▼
                  Arabic Original
                         │
             ┌───────────┴───────────┐
             ▼                       ▼
       Transliteration          Mushaf Renderer
             │                       │
             ▼                       ▼
        Normalizer                Quran UI
             │
             │
Microphone   │
    │        │
    ▼        │
 Quran ASR   │
    │        │
    ▼        │
Recognition  │
    │        │
    └────┬───┘
         ▼
   Matching Engine
         │
         ▼
 Verse Alignment
         │
         ▼
 Murojaah State
         │
    ┌────┴─────┐
    ▼          ▼
 CORRECT     RETRY
    │
    ▼
 Reveal Verse
    │
    ▼
 Next Verse
```

Future:

```text
Audio
 ↓
Quran ASR
 ↓
Phoneme Alignment
 ↓
Pronunciation Analysis
 ↓
Tajweed
 ↓
Makharij
```

---

# 30. MVP Definition of Done

Murojaah MVP dianggap selesai jika:

- [ ] User dapat memilih surat.
- [ ] User dapat memulai Murojaah.
- [ ] Quran ditampilkan RTL seperti mushaf.
- [ ] Semua kata awalnya tersembunyi.
- [ ] Nomor ayat tetap terlihat.
- [ ] User harus membaca secara berurutan.
- [ ] Microphone dapat menerima bacaan.
- [ ] Quran-specific ASR dapat mengenali bacaan.
- [ ] Matching engine dapat menentukan kecocokan.
- [ ] Kata yang benar terbuka satu per satu (hijau).
- [ ] Kata yang salah tetap tersembunyi dan ditandai merah + haptic.
- [ ] Kata yang dilewati terdeteksi (`LcsOmissionDetector`).
- [ ] User tidak dapat skip kata.
- [ ] Progress mengikuti jumlah kata yang berhasil.
- [ ] Surat dapat diselesaikan sampai ayat terakhir.
- [ ] Completion state tersedia.
- [ ] Peek hint (1 kata, 2 detik) tersedia dan dihitung.
- [ ] Skor akurasi tampil di baris progres.
- [ ] Tap kata merah membuka sheet koreksi (seharusnya vs terdengar).
- [ ] Model ASR diunduh on-demand, tidak dibundel di APK.
- [ ] Error handling tersedia.
- [ ] Test untuk matching dan state tersedia.

---

# 31. Long-Term Vision

Murojaah bukan hanya:

> Speech-to-text Quran.

Target akhirnya adalah:

> **Quran memorization assistant yang dapat memahami bacaan pengguna dan memberikan feedback pronunciation secara bertahap.**

Evolution:

```text
MVP
Text Recognition
      ↓
Quran Recognition
      ↓
Word Alignment
      ↓
Phoneme Alignment
      ↓
Pronunciation Analysis
      ↓
Tajweed
      ↓
Makharij
      ↓
Personalized Murojaah Coach
```

Prinsip utama:

> **Build the simplest reliable Murojaah experience first. Improve pronunciation intelligence incrementally.**
