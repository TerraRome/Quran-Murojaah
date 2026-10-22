# Quran Speech Recognition Rules

> **Purpose:** Define the requirements and architecture for speech recognition in Murojaah.
>
> ASR (Automatic Speech Recognition) is responsible for recognizing what the user recited. It is NOT, by itself, a Tajweed or Makharij evaluator.

---

## 1. Primary Goal

The ASR system must answer:

> "What Quranic text did the user most likely recite?"

It should NOT claim:

> "The user's Tajweed is correct."

unless a dedicated pronunciation/tajweed model has been implemented and validated.

---

## 2. Prefer Quran-Specific ASR

Model priority:

```text
Quran-specific ASR
        >
Arabic ASR
        >
General multilingual ASR
```

Quran-specific models should be evaluated first because their training domain is closer to the application's use case.

---

## 3. Model Abstraction

Never tightly couple Murojaah to one ASR provider.

Use an abstraction:

```dart
abstract class SpeechRecognitionService {
  Stream<SpeechResult> recognize(AudioStream audio);
}
```

Possible implementations:

```text
QuranAsrService
WhisperService
OnnxQuranAsrService
CloudSpeechService
```

---

## 4. Local vs Cloud

The architecture must support both:

### Local

```text
Microphone
    ↓
Local Quran ASR
    ↓
Transcript
```

Advantages:

- offline
- privacy
- no per-request API cost

### Cloud

```text
Microphone
    ↓
Cloud ASR
    ↓
Transcript
```

Advantages:

- potentially stronger models
- smaller mobile application
- easier model updates

The application must not assume that cloud is always available.

---

## 5. POC Before Production

Do not integrate the first ASR model directly into the main Flutter application.

First create a POC.

Benchmark candidate models using real Quran recitation recordings.

Possible candidates:

- Quran-specific FastConformer
- Quran STT ONNX
- Quran fine-tuned Whisper
- Whisper baseline

---

## 6. Benchmark Metrics

Every candidate should be evaluated using:

- Word Error Rate (WER)
- Character Error Rate (CER)
- verse recognition accuracy
- word accuracy
- latency
- realtime capability
- model size
- RAM
- CPU
- battery impact
- offline capability

Do not select a model based only on published benchmark numbers.

---

## 7. Real User Audio

Testing must include recordings from actual intended users.

Test different:

- microphones
- environments
- distances
- speaking volumes
- recitation speeds
- background noise
- devices

A model that performs well on a benchmark dataset may perform differently on mobile recordings.

---

## 8. Streaming

If supported, prefer streaming recognition.

Pipeline:

```text
Microphone
    ↓
Audio chunks
    ↓
ASR
    ↓
Partial result
    ↓
Final result
```

Do not validate the verse based on an unstable partial transcript unless the matching engine explicitly supports incremental matching.

---

## 9. Partial vs Final Result

Distinguish:

```text
PARTIAL
```

from:

```text
FINAL
```

Partial:

```text
User is still speaking.
```

Final:

```text
The current speech segment is complete enough to evaluate.
```

Murojaah should generally perform the final acceptance decision using a stable result.

---

## 10. Audio Lifecycle

Handle:

- microphone permission
- microphone unavailable
- audio interruption
- phone call
- app backgrounding
- app foregrounding
- Bluetooth microphone
- headset microphone
- recording failure

Never leave the microphone running unexpectedly.

---

## 11. Speech Segment

The system should determine when a recitation segment begins and ends.

Example:

```text
Silence
 ↓
Speech detected
 ↓
Recitation
 ↓
Short pause
 ↓
Process
```

Avoid submitting every tiny audio chunk as a separate verse attempt.

---

## 12. Language

The primary recognition target is Quranic Arabic.

The system should not assume the user will produce:

```text
English
Indonesian
```

unless the selected ASR explicitly supports those modes.

---

## 13. Recognition Output

ASR result should contain structured information.

Example:

```dart
class SpeechResult {
  final String text;
  final double confidence;
  final bool isFinal;
  final Duration duration;
}
```

Future:

```dart
class SpeechResult {
  final String text;
  final double confidence;
  final bool isFinal;

  final List<RecognizedWord>? words;
  final List<RecognizedPhoneme>? phonemes;
}
```

---

## 14. Matching Pipeline

Never directly compare raw ASR output.

Use:

```text
ASR
 ↓
Detect Result
 ↓
Arabic Normalization
 ↓
Transliteration Normalization
 ↓
Verse Alignment
 ↓
Word Matching
 ↓
Similarity Score
 ↓
Murojaah Decision
```

---

## 15. Verse Constraint

ASR recognition must always be evaluated against the current target verse.

Example:

```text
Current target:
Verse 3
```

If the user accidentally recites Verse 4:

```text
Recognized:
Verse 4
```

Result:

```text
REJECT
```

Verse 4 must remain hidden.

---

## 16. Confidence

ASR confidence and Murojaah confidence are different.

Example:

```text
ASR confidence:
98%

Murojaah matching:
72%
```

Do not treat:

```text
ASR confidence
```

as:

```text
Recitation correctness
```

---

## 17. Matching Threshold

Initial MVP thresholds may be:

```text
>= 95%
    ACCEPT

85-94%
    ALMOST

< 85%
    RETRY
```

These values are starting points only.

They must be configurable and validated using real Quran recitation data.

---

## 18. Wrong Recognition

If ASR produces uncertain or unrelated text:

```text
recognized:
hello
```

or:

```text
empty
```

do not crash.

Return:

```text
RETRY
```

---

## 19. Tajweed Limitation

ASR text matching cannot reliably detect all:

- Tajweed rules
- Makharij
- Madd duration
- Ghunnah
- Qalqalah
- pronunciation subtleties

Therefore MVP feedback must use language such as:

```text
Bacaan berhasil dikenali.
```

or:

```text
Bacaan belum cocok.
```

Avoid:

```text
Tajwid Anda benar.
```

unless a dedicated validated system exists.

---

## 20. Future Phoneme Architecture

The architecture should allow:

```text
Audio
 ↓
Quran ASR
 ↓
Phoneme Recognition
 ↓
Phoneme Alignment
 ↓
Pronunciation Score
```

Eventually:

```text
Pronunciation
 ↓
Tajweed Analysis
 ↓
Makharij Analysis
```

This should be a separate layer from normal ASR.

---

## 21. Privacy

If local ASR is available, prefer local processing for sensitive voice data.

If cloud ASR is used:

- clearly define audio lifecycle
- avoid unnecessary storage
- avoid sending audio when not required
- handle API failures gracefully

---

## 22. Performance

Target for realtime experience:

```text
Low latency
Stable partial results
Fast final result
Low memory usage
```

Do not optimize prematurely.

Measure before optimizing.

---

## 23. Testing

ASR integration tests should cover:

- permission denied
- microphone unavailable
- silence
- short speech
- long speech
- noisy environment
- wrong verse
- correct verse
- partial transcript
- final transcript
- network failure
- local model failure
- app background/foreground

---

## Core Principle

> **ASR recognizes the recitation. Murojaah matching determines whether it matches the expected verse. Tajweed and Makharij require a separate pronunciation-analysis system.**

---

## 24. Implementasi Aktual (pipeline `recite_quran`)

Pipeline lama (Whisper/Vosk + VAD + `speech_to_text`) sudah dihapus. Implementasi
sekarang memakai `package:recite_quran` — on-device, offline, tanpa jaringan saat
runtime.

```text
Microphone (16 kHz PCM16, chunk 480 ms)
    ↓  AudioProcessor (DSP dimatikan: no AEC/NS/AGC)
    ↓  SherpaEngine (zipformer int8, recite_quran_assets/ — unduh on-demand)
    ↓  token fonetis
    ↓  DTW word alignment (isolate)
    ↓  WordMatchedEvent {wordId, isRed, score}
```

Konfigurasi wajib (mode ujian hafalan):

```dart
const TrackerConfig(
  enableAutoReanchor: false,
  reanchorStallThreshold: 24,
)
```

- `wordId` = offset kata global di dalam surah, indeks mengikuti
  `QuranRepository.getSurahWords()` (kata fonetis), **bukan** jumlah token
  Uthmani. Pemetaan kata→ayat dihitung dari daftar itu.
- `enableAutoReanchor: false` membuat lompatan kata tidak dimaafkan; kata yang
  dilewati dilaporkan sebagai event merah, bukan dipulihkan diam-diam.
- Deteksi kata terlupa memakai `LcsOmissionDetector.detectOmission()` dengan
  `phonemesPerWord` dari `getSurahWords()` dan `emittedPhonemes` dari
  `ReciteQuran.onTranscript`.
- Model 69 MB **tidak dibundel**. `ModelDownloader` mengunduhnya ke
  `recite_quran_assets/` saat pertama dibuka, dan `SherpaEngine(assetOverrideDir:)`
  diarahkan ke folder itu. `assets/model/` masuk `.gitignore`; hapus baris aset
  di `pubspec.yaml`. APK release per-ABI jadi ~56 MB (arm64) alih-alih ~125 MB;
  69 MB model diunduh terpisah saat pertama membuka Murojaah.

### Batas akurasi matcher

`matchWord` memakai **free-start** (`dp[i*stride] = 0`): token sampah di awal
buffer gratis, dan token kata yang salah baca menempel ke `cleanAsr` kata
berikutnya. Skor = `1 - pathCost` dengan `pathCost` **dinormalisasi per panjang
kata acuan**, sehingga satu fonem salah pada kata panjang tetap di atas ambang
(`…م` → `…ن` skor 0.857 → hijau). `MatchingStrictness.hard` /
`TrackerConfig.strict()` tidak mengubah hasil: yang bergeser hanya ambang, bukan
normalisasinya.

Konsekuensi di layer app:

- Setiap event **hijau** diverifikasi ulang (`isWrongReading` di
  `heard_word.dart`) dengan membandingkan kerangka konsonan kata acuan vs
  `cleanAsr`. Kesalahan harakat murni tidak terdeteksi (model CTC tidak andal
  pada vokal pendek).
- `WordMatchedEvent.cleanAsr` hanya terisi untuk event hijau;
  `DictationSequencer._commitRed` selalu mengirim `cleanAsr: ''`. Teks
  "terdengar" untuk kata merah direkonstruksi app (`heardForWord`) dari LCS
  fonem ayat ↔ transkrip.
- Tracker tidak punya API reset state; kursor kata hidup di isolate. Ulangi /
  Reset wajib `jumpToWord()` + `resetBuffer()` (`ReciteMurojaahService.rewindTo`).

### Teks Arab

Dataset `recite_quran` menyimpan dua bentuk teks:

| Field | Isi | Dipakai |
|---|---|---|
| `aya_ui` | glyph Private Use Area (U+E000–U+F8FF) untuk font QCF/KFGQPC | ❌ tampil sebagai kotak di font lain |
| `aya_text` | Unicode Arab asli | ✅ render UI |

`QuranVerse.uthmaniWords` berasal dari `aya_ui`, jadi **tidak boleh** dipakai
untuk render. `ReciteMurojaahService` menimpanya dengan kata dari `aya_text`
(jumlah kata identik dengan `aya_phonemes_list` untuk seluruh 6236 ayat).

Font UI: Amiri dibundel sebagai aset (`assets/fonts/Amiri-Regular.ttf`,
`Amiri-Bold.ttf`, family `Amiri`) — bukan unduhan runtime Google Fonts.

### Lisensi

`recite_quran` gratis untuk penggunaan non-komersial. Aplikasi ini tidak menjual
atau mengiklankan apa pun, dan kredit tetap dicantumkan.
