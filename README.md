# Quran App

Aplikasi Flutter untuk belajar dan menghafal Al-Quran. Dimigrasi dari `Flutter-Portfolio` sebagai standalone project.

---

## Fitur yang Sudah Dibangun

### 1. Quran Reader (Core)
Membaca Al-Quran 114 surah lengkap dengan teks Arab Uthmani, transliterasi latin, dan terjemahan Indonesia.

- **Data source**: `assets/quran/quran.json` — data lokal offline (114 surah, semua ayat)
- **Translasi**: `assets/quran/quran_indo_translation.json`
- **Transliterasi**: `assets/quran/quran_transliteration.json` — prefetch di background saat app dibuka
- **Controller**: `QuranController` (ValueNotifier, tanpa Bloc) — load surah list, track last read
- **Repository**: `QuranRepositoryImpl` → `QuranAssetDataSource` (baca JSON dari asset)
- **Last read**: disimpan ke `SharedPreferences` via `LastReadStore`
- **Font size**: bisa diubah user, disimpan lokal via `FontSizeStore`
- **Pages**: `QuranHomePage` (daftar surah + last read banner), `SurahDetailPage` (baca per ayat), `QuranSplashPage`, `FontSizeSettings`
- **Widgets**: `SurahCard`, `SurahHeaderCard`, `VerseView`, `QuranTopBar`, `QuranStatusBar`, `QuranThemeScope`

### 2. Murojaah (Hafalan dengan Speech Recognition)
Fitur utama — user membaca ayat dari hafalan, app mendengarkan dan menilai kebenaran bacaan.

#### Pipeline Lengkap

```
Mikrofon → VAD → AudioBuffer → WAV → AudioPreprocessor → ONNX Model → TokenDecoder → Transkrip Arab
                                                                                           ↓
                                                                              QuranNormalizer (E3 resegment)
                                                                                           ↓
                                                                              WordAligner (DP alignment)
                                                                                           ↓
                                                                           MurojaahMatchResult (accept/retry/reject)
```

#### Sub-komponen

**ASR (Automatic Speech Recognition)**
- Model: `assets/models/model_int8.onnx` — Quran-specific ONNX model (INT8 quantized)
- Vocab: `assets/models/tokenizer_vocab.json` — BPE tokenizer vocabulary
- `AudioPreprocessor` — konversi 16-bit PCM WAV → log-mel spectrogram (n_fft=512, hop=160, n_mels=80, 16kHz), matching pipeline Python/librosa POC
- `QuranOnnxRecognizer` — load model dari asset, warmUp(), transcribeWav(), transcribeSamples(); precompute Hann window & mel filterbank sekali pakai
- `TokenDecoder` — CTC/BPE decode dari ONNX output token IDs ke teks Arab
- `QuranAsrResult` — hasil transkrip dengan metadata (durasi, confidence, dll)

**Audio Recording & VAD**
- `RecordAudioRecorder` — wrapper `record` package, 16kHz mono PCM
- `StreamingRecordAudioRecorder` — streaming mode untuk utterance segmentation real-time
- `MurojaahAudioBuffer` — buffer PCM samples dengan sampleRate & channels
- `EnergyVad` — RMS-based VAD, threshold=0.015, frame=20ms, classifies speech/silence per frame
- `VadConfig` — konfigurasi: speechThreshold, consecutiveSpeechFrames=3, consecutiveSilenceFrames=35, preSpeechPaddingMs=200, postSpeechPaddingMs=200, maxUtteranceDurationMs=8000
- `MurojaahUtteranceSegmenter` — segmentasi utterance dari stream audio via VAD
- `WavEncoder` — encode Float32List samples → WAV bytes (16-bit PCM header)

**Matching Engine (port dari Python POC)**
- `QuranNormalizer` — normalisasi teks Arab konservatif (2 level: light & aggressive); port dari `docs/quran/murojaah/poc/normalizer.py`
  - `normalizeLight` — strip harakat minor, normalisasi أ/إ/آ/ى/ة
  - `normalizeAggressive` — strip semua harakat
  - `resegmentFusedWords` (E3) — pisahkan kata yang tergabung oleh ONNX decoder (contoh: `"اللَّهَُحَدٌ"` → `"اللَّهُ أَحَدٌ"`)
  - `tokenize` — split teks Arab ke list kata
- `NormalizedWord` — pair (raw, light, aggressive) untuk DP alignment
- `WordAligner` — DP sequence alignment expected vs recognized, per-word match type (MATCH_EXACT / MATCH_LIGHT / MATCH_AGGRESSIVE / NO_MATCH)
- `MurojaahMatchResult` — hasil alignment: decision (accept/retry/reject), score, word counts, per-word detail
- `MurojaahMatcher` — public stateless facade: `MurojaahMatcher.match(expected, recognized)`, threshold=0.80 (validated 12/12 true accept, 0/9 false accept di POC)
- `ArabicMatcher` — matcher lama (masih dipakai): acceptThreshold=0.90, almostThreshold=0.75; handle muqatta'at (الم, يس, dll); pipeline A (Arabic STT) & B (Latin STT)

**State & Session**
- `MurojaahController` (ValueNotifier) — state machine: idle→listening→validating→revealed/error; track revealed ayat, accumulatedTranscript, incorrectAttempts; helpThreshold=3, longVerseWordThreshold=15
- `MurojaahRecitationSession` — sesi rekam + ASR + match dalam satu unit; event-driven via `RecitationSessionEvent`
- `MurojaahSessionState` — state immutable sesi (phase: initial/running/completed, status, matchResult, murojaahDecision)
- `SpeechRecognizer` — abstraksi STT, implementasi via ONNX recognizer
- `VerseSpeaker` — TTS pembacaan ayat (flutter_tts), dipakai saat user butuh bantuan (setelah 3x salah)
- `MurojaahDependencies` — factory wiring semua komponen murojaah

**Presentation**
- `MurojaahPage` — halaman utama murojaah per surah
- `MurojaahPageShell` — shell navigation wrapper (terima surahNumber dari router)
- `MurojaahMushaf` — widget tampilan mushaf dengan reveal/blur per ayat
- `MushafdRendererPage` — renderer mushaf standalone
- POC pages (dev only): `AsrE2eRunnerPage`, `AudioCapturePocPage`, `VadPocPage`

### 3. Murottal (Audio Quran)
Mendengarkan murottal per surah dengan pilihan qari.

- **API**: `equran.id/api/v2` — fetch audio URL dan metadata qari
- `EquranRemoteDataSourceImpl` — Dio HTTP client, timeout connect=15s receive=30s; Alice inspector terintegrasi (debug)
- `MurottalController` (ValueNotifier) — state playback: idle/loading/playing/paused/error; just_audio backend
- `DownloadController` — download file audio lokal: idle→checkingSize→ready→inProgress→completed/failed; progress%, ETA, speed label
- `QariStore` — simpan pilihan qari user ke SharedPreferences
- `AudioLocalDataSource` — baca/tulis file audio lokal (path_provider)
- `SurahAudioModel`, `SurahLatinModel` — model JSON response equran.id
- **Pages**: `MurottalSettingsPage`
- **Widgets**: `MiniPlayer` (persistent player bar), `DownloadProgressDialog`

### 4. Tafsir
Tafsir per ayat dalam bottom sheet, dari API equran.id.

- `TafsirController` (ValueNotifier) — state: idle/loading/loaded/error; in-memory cache per surah (fetch sekali per session)
- `TafsirResponseModel` — model JSON response tafsir
- `TafsirEntity` — domain entity tafsir
- **Widget**: `TafsirBottomSheet` — bottom sheet scrollable, aktif dari SurahDetailPage

### 5. Doa
Daftar doa harian dengan teks Arab, transliterasi, dan terjemahan.

- `DoaController` (ValueNotifier)
- `DoaLocalDataSource` — baca dari asset JSON
- `DoaRemoteDataSource` — fetch dari remote bila diperlukan
- `DoaModel` / `DoaEntity`
- **Pages**: `DoaListPage`
- **Widgets**: `DoaCard`

### 6. Jadwal Shalat
Jadwal shalat berdasarkan lokasi GPS user dengan notifikasi.

- `ShalatController` (ValueNotifier) — load jadwal, pilih lokasi
- `LocationService` — geolocator, GPS permission handling
- `NotificationService` — flutter_local_notifications, alarm per waktu shalat
- `ShalatRemoteDataSource` — fetch jadwal dari API (Dio)
- `ShalatLocalDataSource` — cache jadwal lokal
- `JadwalShalatModel`, `WaktuShalatModel` — model JSON
- `JadwalShalat`, `WaktuShalat` — domain entities
- **Pages**: `ShalatPage`
- **Widgets**: `LokasiSelectorSheet`

---

## Arsitektur

Pattern yang dipakai konsisten di semua fitur:

```
presentation/          ← Widget + Page (hanya observe state, trigger action)
    pages/
    widgets/
application/           ← Controller (ValueNotifier) + state classes
data/
    datasources/       ← Remote (Dio) + Local (asset/SharedPreferences/file)
    models/            ← JSON serialization
    repositories/      ← implementasi Repository
domain/
    entities/          ← immutable domain objects
    repositories/      ← abstract interface
    failures/          ← sealed error types
```

Keputusan arsitektur:
- **State management**: ValueNotifier murni (tanpa Bloc/Riverpod) — sesuai keputusan project
- **Error handling**: `fpdart` Either<Failure, T> di layer repository
- **No code generation**: State classes dibuat manual (tanpa freezed) — keputusan eksplisit
- **No DI framework**: Dependency injection manual via konstruktor
- **Routing**: go_router (nested navigation via QuranShellPage)

---

## Struktur File Project

```
lib/
└── Quran/
    ├── application/               # Core Quran controllers
    │   ├── quran_controller.dart
    │   ├── quran_dependencies.dart
    │   ├── last_read.dart
    │   └── transliteration_prefetch_service.dart
    ├── data/
    │   ├── datasources/
    │   │   ├── quran_asset_datasource.dart   # Baca quran.json dari asset
    │   │   ├── equran_remote_datasource.dart # API equran.id
    │   │   ├── audio_local_datasource.dart
    │   │   └── transliteration_local_datasource.dart
    │   ├── models/
    │   │   ├── surah_audio_model.dart
    │   │   ├── surah_latin_model.dart
    │   │   └── tafsir_response_model.dart
    │   ├── repositories/
    │   │   └── quran_repository_impl.dart
    │   ├── font_size_store.dart
    │   ├── last_read_store.dart
    │   └── quran_tokens.dart
    ├── domain/
    │   ├── entities/ (surah.dart, verse.dart, qari.dart, tafsir.dart)
    │   ├── failures/ (quran_failure.dart)
    │   └── repositories/ (quran_repository.dart)
    ├── presentation/
    │   ├── pages/ (quran_home_page, surah_detail_page, quran_splash_page, font_size_settings)
    │   └── widgets/ (surah_card, verse_view, quran_top_bar, quran_status_bar, quran_theme_scope, surah_header_card)
    ├── murojaah/
    │   ├── application/ (murojaah_controller, murojaah_recitation_session, arabic_matcher, speech_recognizer, verse_speaker, murojaah_dependencies)
    │   ├── domain/ (murojaah_matcher, quran_normalizer, word_aligner, murojaah_match_result)
    │   ├── infrastructure/
    │   │   ├── asr/ (quran_onnx_recognizer, audio_preprocessor, token_decoder, quran_onnx_model, quran_asr_result)
    │   │   └── audio/ (energy_vad, murojaah_audio_recorder, murojaah_audio_buffer, murojaah_utterance_segmenter, record_audio_recorder, streaming_record_audio_recorder, wav_encoder, murojaah_vad)
    │   └── presentation/
    │       ├── pages/ (murojaah_page, murojaah_page_shell, murojaah_mushaf — + 3 POC pages)
    │       └── widgets/ (murojaah_mushaf)
    ├── murottal/
    │   ├── application/ (murottal_controller, download_controller, qari_store)
    │   └── presentation/
    │       ├── pages/ (murottal_settings_page)
    │       └── widgets/ (mini_player, download_progress_dialog)
    ├── tafsir/
    │   ├── application/ (tafsir_controller)
    │   └── presentation/widgets/ (tafsir_bottom_sheet)
    ├── doa/
    │   ├── application/ (doa_controller)
    │   ├── data/ (datasources, models)
    │   ├── domain/entities/ (doa.dart)
    │   └── presentation/ (pages: doa_list_page, widgets: doa_card)
    └── shalat/
        ├── application/ (shalat_controller, location_service, notification_service)
        ├── data/ (datasources, models)
        ├── domain/entities/ (jadwal_shalat, waktu_shalat)
        └── presentation/ (pages: shalat_page, widgets: lokasi_selector_sheet)

assets/
├── quran/
│   ├── quran.json                      # Data 114 surah + semua ayat (teks Arab Uthmani)
│   ├── quran_indo_translation.json     # Terjemahan Indonesia per ayat
│   ├── quran_transliteration.json      # Transliterasi latin per ayat
│   ├── quran_normalizer.json           # Data normalizer untuk matching
│   └── *.svg                           # Icons & ilustrasi Quran
├── models/
│   ├── model_int8.onnx                 # ONNX ASR model (INT8 quantized, Quran-specific)
│   └── tokenizer_vocab.json            # BPE vocabulary untuk token decoder
└── fonts/
    ├── NotoNaskhArabic-Regular.ttf
    ├── NotoNaskhArabic-SemiBold.ttf
    ├── Poppins-Regular.ttf
    └── Poppins-SemiBold.ttf

docs/quran/
├── PRD.md                              # Product Requirements Document
├── PRD_MUROTTAL_TAFSIR.md
├── PLAN.md                             # Rencana implementasi
├── TASKS.md                            # Task tracking
├── DECISIONS.MD                        # Architecture Decision Records
└── murojaah/
    ├── README.MD                       # Murojaah rules & milestone guide
    └── poc/                            # Python POC (dasar implementasi Dart)
        ├── normalizer.py               # Port → quran_normalizer.dart
        ├── matching.py                 # Port → murojaah_matcher.dart + word_aligner.dart
        ├── aligner.py
        ├── export_mel_reference.py
        ├── requirements.txt
        ├── model_cache/onnx/model_int8.onnx
        └── results/ (batch_test.json, matching_report.json)
```

---

## Tests

```
test/
├── unit/quran/
│   └── murojaah/
│       ├── murojaah_controller_test.dart
│       ├── murojaah_matcher_test.dart
│       ├── quran_normalizer_test.dart
│       ├── word_aligner_test.dart
│       ├── application/
│       │   ├── murojaah_recitation_session_test.dart
│       │   ├── fake_quran_asr_engine.dart
│       │   └── fake_utterance_segmenter.dart
│       ├── fakes/
│       │   └── fake_speech_recognizer.dart
│       └── infrastructure/
│           ├── asr/ (audio_preprocessor_test, quran_asr_result_test, token_decoder_test)
│           └── audio/ (energy_vad_test, murojaah_audio_buffer_test, murojaah_audio_recorder_test, murojaah_utterance_segmenter_test, streaming_record_audio_recorder_test)
├── widget/
│   ├── features/quran/
│   │   ├── font_size_settings_test.dart
│   │   ├── quran_home_page_test.dart
│   │   ├── surah_card_test.dart
│   │   ├── surah_detail_page_test.dart
│   │   ├── surah_header_card_test.dart
│   │   ├── verse_view_test.dart
│   │   ├── murojaah/ (arabic_matcher_test, murojaah_controller_test, murojaah_mushaf_test, murojaah_page_shell_test, mushaf_renderer_page_test, speech_recognizer_test)
│   │   └── murottal/ (equran_datasource_test)
│   └── quran/murojaah/presentation/pages/ (audio_capture_poc_page_test, vad_poc_page_test)
└── integration/quran/murojaah/
    └── quran_onnx_benchmark_test.dart  # Benchmark ONNX inference end-to-end
```

Jalankan semua test:
```bash
fvm flutter test
```

Jalankan hanya unit test murojaah:
```bash
fvm flutter test test/unit/quran/murojaah/
```

---

## Dependencies Utama

| Package | Versi | Dipakai untuk |
|---|---|---|
| `go_router` | ^17.3.0 | Routing & nested navigation |
| `fpdart` | ^1.1.1 | Either<Failure, T> error handling |
| `dio` | ^5.7.0 | HTTP client (equran.id API) |
| `shared_preferences` | ^2.3.4 | Last read, font size, qari preference |
| `flutter_onnxruntime` | ^1.8.3 | ONNX inference (ASR model) |
| `record` | ^6.2.1 | Rekam audio mikrofon |
| `flutter_tts` | ^4.2.5 | TTS bacaan ayat (bantuan murojaah) |
| `just_audio` | ^0.9.40 | Playback murottal |
| `flutter_svg` | ^2.0.16 | SVG assets (icons) |
| `google_fonts` | ^8.2.0 | Typography |
| `flutter_animate` | ^4.5.2 | Animasi UI |
| `geolocator` | ^13.0.2 | GPS untuk jadwal shalat |
| `flutter_local_notifications` | ^19.5.0 | Notifikasi waktu shalat |

---

## API Eksternal

- **equran.id v2** — `https://equran.id/api/v2`
  - `GET /surat/{nomor}` — detail surah, URL audio per ayat, teksLatin
  - `GET /tafsir/{nomor}` — tafsir lengkap per ayat

---

## TODO (Konfigurasi Setelah Migrasi)

- [ ] Sambungkan `lib/main.dart` ke entry point Quran yang benar
- [ ] Setup `android/` — copy manifest, permissions (RECORD_AUDIO, INTERNET, ACCESS_FINE_LOCATION, RECEIVE_BOOT_COMPLETED)
- [ ] Setup `ios/` — copy Info.plist permissions (microphone, location)
- [ ] Jalankan `fvm flutter pub get`
- [ ] Jalankan `dart run build_runner build` jika ada code generation
- [ ] Inisialisasi DI / wiring dependencies di main.dart
- [ ] Konfigurasi go_router routes

---

## Catatan Penting

- Semua state management menggunakan **ValueNotifier** — tidak ada Bloc, Riverpod, atau GetX
- State classes dibuat **manual** (tanpa freezed) — keputusan eksplisit project
- Data Quran (quran.json) dibaca dari **asset lokal** — tidak butuh internet untuk baca Al-Quran
- ONNX model sudah **INT8 quantized** — lebih kecil dan lebih cepat di mobile
- Matching engine adalah **port Dart** dari Python POC di `docs/quran/murojaah/poc/`
- Threshold matching: **0.80** (MurojaahMatcher), **0.90 accept / 0.75 almost** (ArabicMatcher legacy)
- Sebelum modifikasi Murojaah, baca `docs/quran/murojaah/README.MD` untuk rule dan milestone guide
