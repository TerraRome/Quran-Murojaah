# Quran App — Roadmap

Dokumen ini merekam apa yang sudah selesai, sedang berjalan, dan akan diimplementasi.
Diperbarui berdasarkan session terakhir: **Agustus 2026**.

---

## Status Singkat

| Fitur | Status |
|---|---|
| Quran Reader (Core) | ✅ Selesai |
| Polish UI | ✅ Selesai (mayoritas) |
| Murojaah — Foundation | ✅ Selesai |
| Murojaah — Mushaf Renderer | ✅ Selesai |
| Murojaah — State Machine | ✅ Selesai |
| Murojaah — Speech Recognition | ✅ Selesai |
| Murojaah — Matching Engine (ArabicMatcher) | ✅ Selesai |
| Murojaah — ONNX ASR Pipeline | ✅ Selesai |
| Murojaah — TTS Bantuan | ✅ Selesai |
| Murojaah — Polish & UX | 🔵 Selanjutnya |
| Murottal (Audio Player) | 🟡 Infrastruktur ada, belum di-wire |
| Tafsir | 🟡 Controller ada, belum di-wire ke UI |
| Doa | 🟡 Struktur ada, belum di-wire |
| Jadwal Shalat | 🟡 Struktur ada, belum di-wire |
| Bookmark per-ayat | ⬜ Belum dimulai |
| Multi Qari | ⬜ Belum dimulai |

---

## Sudah Selesai

### Fase 1 — Data & Fondasi
- Struktur folder `lib/Quran/{domain,data,application,presentation}`
- Entity `Surah`, `Verse`, `Qari`, `Tafsir` — immutable, tanpa codegen
- Sealed `QuranFailure` (asset load / parse)
- `QuranRepository` abstract + `QuranRepositoryImpl`
- `QuranAssetDataSource` — load `assets/quran/quran.json` (114 surah, 6236 ayat) + cache memori
- Route `/home/quran*` + entry card di HomePage
- `QuranThemeScope` + `QuranTokens`

### Fase 2 — UI Baca
- `QuranSplashPage` — layout pixel-perfect Figma, SVG ilustrasi asli, basmalah SVG
- `QuranHomePage` — greeting, Last Read card (mushaf watermark), bottom tab icon-only (Quran/Murojaah/Shalat/Doa/Bookmark), search live-filter, shimmer loading, CustomScrollView (scroll seluruh halaman)
- `SurahDetailPage` — header card gradient + mushaf watermark, daftar ayat, nav prev/next
- `SurahCard`, `SurahHeaderCard`, `VerseView` (strip header + badge lingkaran + 3 ikon)
- `QuranTopBar`, `QuranStatusBar`, `QuranThemeScope`
- Last-read persistence (SharedPreferences) + `LastReadStore`
- Font size settings — `FontSizeStore`, slider Arab (14–36) + terjemahan (12–28), preview live
- Toggle dark/light

### Fase 3 — Polish UI
- Search surah (nama latin + arti)
- Navigasi prev/next surah
- Toggle dark/light sinkron antar halaman
- Bahasa Indonesia global (Mekkah/Madinah, Ayat)
- Semua SVG aset dari Figma (bismillah, mushaf, muslim_avatar, quran, lamp, shalat, doa, bookmark, share, play, menu_line, search_line)
- Bug fix scroll home (CustomScrollView) + bug fix scroll detail (CrossAxisAlignment.stretch)

### Murojaah — Milestone 1: Foundation
- Tab `Murojaah` di bottom nav (ganti Lamp)
- `MurojaahController` (ValueNotifier) — state machine: phase (initial/running/completed) + status (idle/listening/validating/revealed/error)
- Route `/home/quran/murojaah` + `MurojaahPage` (daftar surah)

### Murojaah — Milestone 2: Mushaf Renderer
- `MurojaahMushaf` — satu aliran teks RTL semua ayat, penanda `۝` arab-indik
- Sistem hidden/reveal: ayat tersembunyi warna background (invisible tapi tetap menempati layout — zero layout shift)
- `MushafRendererPage` — top bar + mushaf + debug controls
- Route `/home/quran/murojaah/surah/:number`

### Murojaah — Milestone 3: State Machine
- Siklus murojaah penuh: `start()`, `tryReveal()` (validasi urutan), `markCorrect()`, `resetReveal()`
- Progress bar + label "Ayat X / N"
- Auto-scroll ke ayat aktif (TextPainter.getBoxesForSelection + animateTo 350ms)
- State: initial → prompt Mulai; running → progress + kontrol; completed → Selesai + Mulai Ulang

### Murojaah — Milestone 4: Speech Recognition
- `SpeechRecognizer` abstraksi + `SpeechToTextRecognizer` (speech_to_text ^7.4.0)
- `SpeechSession` (ValueNotifier) — status: idle/initializing/listening/recognized/unavailable/error
- Izin RECORD_AUDIO (Android) + NSMicrophoneUsageDescription (iOS)
- `_SpeechPanel` — status live + transkrip partial + detail error asli plugin
- Pengecekan `isAvailable` + `hasPermission` sebelum listen
- Fallback graceful saat STT tidak tersedia

### Murojaah — Milestone 5: Matching Engine (ArabicMatcher)
- `ArabicMatcher` — normalisasi harakat, variasi huruf (أإآٱ→ا, ة→ه, ى→ي), muqatta'at
- Containment matching berurutan, toleransi edit-distance 1 untuk kata ≥4 huruf
- Threshold: accept=0.90, almost=0.75
- `MurojaahController.validate()` — benar → reveal + maju; salah → tetap ayat + feedback
- `MurojaahFeedback` enum (none/correct/incorrect) di state
- Feedback UI: "Benar!" (brand color) / "Belum tepat. Coba lagi." (secondary)

### Murojaah — Matching Engine v2 (MurojaahMatcher + ONNX ASR)
- `QuranNormalizer` — port dari Python POC (`normalizer.py`): light + aggressive, `resegmentFusedWords` (E3)
- `NormalizedWord` — pair (raw, light, aggressive) untuk DP alignment
- `WordAligner` — DP sequence alignment, per-word match type (EXACT/LIGHT/AGGRESSIVE/NO_MATCH)
- `MurojaahMatchResult` — decision (accept/retry/reject), score, per-word detail
- `MurojaahMatcher` — stateless facade, threshold=0.80 (validated 12/12 true accept, 0/9 false accept)
- `AudioPreprocessor` — WAV 16kHz → log-mel spectrogram (n_fft=512, hop=160, n_mels=80), matching Python/librosa POC
- `QuranOnnxRecognizer` — load `model_int8.onnx` dari asset, warmUp(), transcribeWav(), transcribeSamples()
- `TokenDecoder` — CTC/BPE decode token IDs → teks Arab
- `EnergyVad` — RMS-based VAD, threshold=0.015, frame=20ms
- `MurojaahAudioRecorder`, `StreamingRecordAudioRecorder`, `WavEncoder`, `MurojaahAudioBuffer`
- `MurojaahRecitationSession` — event-driven session (record → ASR → match)
- `VerseSpeaker` abstraksi + `FlutterTtsVerseSpeaker` (ar-SA, rate=0.35)
- TTS bantuan setelah 3x salah beruntun (`helpThreshold=3`), `longVerseWordThreshold=15`

### Infrastruktur Tersedia (belum di-wire ke UI utama)
- `EquranRemoteDataSourceImpl` — Dio HTTP ke equran.id/api/v2; endpoint: `/surat/{n}`, `/tafsir/{n}`
- `MurottalController` — state: idle/loading/playing/paused/error (just_audio)
- `DownloadController` — state: idle/checkingSize/ready/inProgress/completed/failed
- `QariStore` — pilihan qari di SharedPreferences
- `TafsirController` — fetch + in-memory cache per surah
- `TafsirBottomSheet` — widget bottom sheet tafsir per ayat
- `ShalatController` + `LocationService` + `NotificationService`
- `DoaController` + `DoaListPage` + `DoaCard`

### Tests (total 56+ test Quran)
- Unit: `QuranNormalizer`, `WordAligner`, `MurojaahMatcher`, `MurojaahController`, `ArabicMatcher`
- Unit infra: `AudioPreprocessor`, `TokenDecoder`, `QuranAsrResult`, `EnergyVad`, `MurojaahAudioBuffer`, `MurojaahAudioRecorder`, `MurojaahUtteranceSegmenter`, `StreamingRecordAudioRecorder`
- Unit session: `MurojaahRecitationSession`
- Widget: `QuranHomePage`, `SurahCard`, `SurahDetailPage`, `SurahHeaderCard`, `VerseView`, `FontSizeSettings`, `MurojaahMushaf`, `MushafRendererPage`, `MurojaahPageShell`, `SpeechRecognizer`, `VadPocPage`, `AudioCapturePocPage`
- Integration: `QuranOnnxBenchmark` (ONNX inference end-to-end)

---

## Sedang Berjalan / Selanjutnya

### Murojaah — Polish & UX
Matching engine ONNX sudah ada tapi belum di-wire ke UI utama `MushafRendererPage`.
Saat ini UI murojaah masih pakai `ArabicMatcher` (v1) + `speech_to_text` plugin.

- [ ] Wire `MurojaahRecitationSession` (ONNX pipeline) ke `MushafRendererPage`
- [ ] Ganti `speech_to_text` → `record` package + ONNX ASR (pipeline internal)
- [ ] Tampilkan confidence score / per-word feedback di mushaf (kata salah highlight merah)
- [ ] Multi-rekam untuk ayat panjang (tombol "Selesai" saat wordCount ≥ 15)
- [ ] Akumulasi transkrip antar rekaman (`accumulatedTranscript`)
- [ ] Animasi reveal ayat (fade/slide saat ayat ter-unlock)
- [ ] Suara feedback (benar/salah) selain TTS

### Murottal (Audio Player)
Infrastruktur sudah ada, belum di-wire ke tab Shalat/tombol play di VerseView.

- [ ] Wire tombol play per ayat (`VerseView`) → `MurottalController`
- [ ] Wire tombol play full surah (`SurahHeaderCard`) → `MurottalController`
- [ ] `MiniPlayer` persistent di bottom (over bottom tab)
- [ ] Setting qari (dropdown) di halaman Settings
- [ ] Download per surah + `DownloadManagerPage`

### Tafsir
- [ ] Wire ikon tafsir di `VerseView` → `TafsirBottomSheet`
- [ ] Cache offline (Hive)
- [ ] Navigasi prev/next ayat dalam bottom sheet tanpa tutup

### Jadwal Shalat
- [ ] Wire `ShalatController` ke tab Shalat
- [ ] `ShalatPage` — tampilkan jadwal 5 waktu berdasarkan lokasi
- [ ] `LokasiSelectorSheet` — pilih lokasi manual bila GPS tidak aktif
- [ ] Notifikasi waktu shalat (flutter_local_notifications)

### Doa
- [ ] Wire `DoaController` ke tab Doa
- [ ] `DoaListPage` + `DoaCard` sudah ada, perlu di-mount ke tab

---

## Backlog (Belum Dimulai)

- Bookmark per-ayat (icon di VerseView → simpan ke SharedPreferences)
- Multi qari di Murottal (pilih qari → download ulang bila perlu)
- Pencarian ayat (bukan hanya nama surah)
- Mode baca tanpa terjemahan (full Arab)
- Progress hafalan per surah (berapa % sudah di-murojaah)
- Notifikasi pengingat murojaah harian
- Offline tafsir lengkap (bundle JSON di asset)
- Widget flutter (home screen) jadwal shalat
- Onboarding pertama kali (pilih bahasa terjemahan, ukuran font)
- iPad / tablet layout

---

## Keputusan Teknis yang Tidak Boleh Diubah

| Keputusan | Alasan |
|---|---|
| ValueNotifier (bukan Bloc/Riverpod) | Konsisten dengan pola project |
| State class manual (bukan freezed) | Keputusan eksplisit — tanpa codegen |
| No DI framework | Injeksi manual via konstruktor |
| Data Quran dari asset lokal | Offline-first — tidak butuh internet untuk baca |
| ONNX model INT8 quantized | Lebih kecil + lebih cepat di mobile |
| Matching threshold 0.80 (MurojaahMatcher) | Validated 12/12 true accept, 0/9 false accept di POC Python |
| Matching threshold 0.90/0.75 (ArabicMatcher legacy) | Ketat sesuai permintaan user |
| TTS bahasa ar-SA, rate=0.35 | Lambat agar jelas untuk hafalan |
| Bantuan TTS setelah 3x salah, tanpa auto-lanjut | User harus tetap mencoba sendiri |

---

## Referensi

- Figma: `Yt0SDawZq88QBXq4yvHuvT` — "Quran App Concept - Free (Community)"
- API: `https://equran.id/api/v2` — surat, tafsir, audio
- ONNX POC: `docs/quran/murojaah/poc/` — normalizer.py, matching.py, aligner.py
- Docs: `docs/quran/PRD.md`, `PLAN.md`, `TASKS.md`, `DECISIONS.MD`
