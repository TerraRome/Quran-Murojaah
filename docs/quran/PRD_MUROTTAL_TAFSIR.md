# PRD — Murottal & Tafsir (Quran Module)

> Ekstensi fitur Quran module dengan integrasi API equran.id v2.0.
> Dua fitur utama: **Murottal** (audio bacaan Quran) + **Tafsir** (penjelasan ayat).
> Dikerjakan secara paralel, diimplementasi phase by phase.

---

## 1. API Source: equran.id v2.0

**Base URL:** `https://equran.id/api/v2`

### Endpoint yang digunakan

| Endpoint | Fungsi |
|----------|--------|
| `GET /surat/{nomor}` | Detail surah + audio per ayat + audio full surah |
| `GET /tafsir/{nomor}` | Tafsir lengkap per ayat |

### Struktur Audio (dari `/surat/{nomor}`)

```json
{
  "audioFull": {
    "01": "https://cdn.equran.id/audio-full/Abdullah-Al-Juhany/001.mp3",
    "05": "https://cdn.equran.id/audio-full/Misyari-Rasyid-Al-Afasi/001.mp3"
  },
  "ayat": [{
    "nomorAyat": 1,
    "audio": {
      "01": "https://cdn.equran.id/audio-partial/Abdullah-Al-Juhany/001001.mp3",
      "05": "https://cdn.equran.id/audio-partial/Misyari-Rasyid-Al-Afasi/001001.mp3"
    }
  }]
}
```

### 6 Qari Tersedia

| ID | Nama |
|----|------|
| 01 | Abdullah Al-Juhany |
| 02 | Abdul Muhsin Al-Qasim |
| 03 | Abdurrahman As-Sudais |
| 04 | Ibrahim Al-Dossari |
| 05 | Misyary Rasyid Al-Afasy |
| 06 | Yasser Al-Dosari |

### Struktur Tafsir (dari `/tafsir/{nomor}`)

```json
{
  "tafsir": [
    {
      "ayat": 1,
      "teks": "Teks tafsir panjang per ayat..."
    }
  ]
}
```

---

## 2. Fitur A — Murottal

### 2.1 User Stories

**US-MR-01: Putar Murottal Full Surah**
Sebagai pengguna, saya ingin memutar murottal satu surah penuh, sehingga saya bisa mendengarkan bacaan Al-Quran sambil membaca.

**US-MR-02: Putar Murottal Per Ayat**
Sebagai pengguna, saya ingin memutar bacaan satu ayat tertentu, sehingga saya bisa mengulang ayat yang ingin dipelajari.

**US-MR-03: Pilih Qari**
Sebagai pengguna, saya ingin memilih qari favorit saya, sehingga saya bisa mendengarkan suara qari yang saya sukai.

**US-MR-04: Download Audio Surah**
Sebagai pengguna, saya ingin mengunduh audio surah untuk didengarkan offline, sehingga saya tidak perlu koneksi internet terus-menerus.

**US-MR-05: Manajemen Download**
Sebagai pengguna, saya ingin melihat surah mana saja yang sudah diunduh dan bisa menghapusnya, sehingga saya bisa mengelola penyimpanan.

### 2.2 Keputusan Design

| Aspek | Keputusan | Alasan |
|-------|-----------|--------|
| Download unit | Full surah saja | Satu file, simple management; per-ayat cukup streaming |
| Qari selection | Global (berlaku semua surah) | User biasanya punya qari favorit yang konsisten |
| Player mode | Global bottom sheet (mini player) + inline per ayat | User pilih mode via toggle; seperti Spotify |
| Offline fallback | Streaming jika tidak ada download | Tidak force download; tetap bisa dipakai tanpa download |

### 2.3 Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| MR-01 | Tombol play di setiap ayat di surah detail (inline di VerseView, dekat share/play/bookmark) | P0 |
| MR-02 | Mini player global (bottom sheet persistent) saat audio sedang berjalan | P0 |
| MR-03 | Tombol play full surah di header card surah detail | P0 |
| MR-04 | Pilih qari di halaman Settings Quran | P0 |
| MR-05 | Informasi ganti qari → perlu download ulang (jika belum ada audio qari baru) | P0 |
| MR-06 | Tombol download per surah (di detail surah) | P1 |
| MR-07 | Informasi estimasi durasi/ukuran sebelum download, warning surah panjang | P1 |
| MR-08 | Progress download dengan persentase | P1 |
| MR-09 | Halaman Download Manager (list downloaded + hapus) | P1 |
| MR-10 | Audio tetap berjalan saat layar mati / app di background | P2 |
| MR-11 | Kontrol playback: play/pause, seek, kecepatan (0.5x–2x) | P1 |

### 2.4 UI Specification

#### A. VerseView — Tombol Play Ayat (inline)
```
[strip header abu]
  [● badge nomor]  [share] [▶ play] [bookmark]
                              ↑
                    tap → putar ayat ini via mini player
```
- Tap play → mini player muncul di bottom, mulai putar ayat tersebut
- Jika audio ayat ini sedang diputar → ikon berubah jadi ■ (stop/pause)

#### B. SurahHeaderCard — Play Full Surah
```
[Header Card gradient]
  Al-Fatihah
  Pembukaan
  ─────────
  Mekkah · 7 Ayat
  [bismillah.svg]
  [▶ Putar Surah]   [⬇ Download]
```
- Tombol `▶ Putar Surah` → mini player muncul, putar full surah
- Tombol `⬇ Download` → mulai download, tampilkan progress
- Jika sudah di-download → ikon centang + tombol hapus

#### C. Mini Player (Global Bottom Sheet)
```
┌─────────────────────────────────────────┐
│  [▶/⏸]  Al-Fatihah • Ayat 1/7         [×]│
│  ════════════░░░░░░░░░░  02:14 / 05:30  │
│  [|◀] [⏮] [▶/⏸] [⏭] [▶|]    [0.75x]  │
└─────────────────────────────────────────┘
```
- Kontrol: prev ayat, play/pause, next ayat
- Seek bar dengan posisi waktu
- Kecepatan: 0.5x, 0.75x, 1x, 1.25x, 1.5x, 2x
- Dismiss [×] untuk menutup player

**Mode Player (user bisa pilih):**
- **Mode A — Inline**: play per ayat, highlight ayat aktif di list, tanpa bottom sheet
- **Mode B — Mini Player**: bottom sheet persistent seperti Spotify, bisa scroll surah

Setting mode player ada di Settings Quran.

#### D. Settings Quran — Murottal Section
```
Pengaturan Murottal
────────────────────
Qari           [Misyary Rasyid Al-Afasy  ▾]
Mode Player    [Mini Player             ▾]

Audio Tersimpan
────────────────────
Al-Fatihah     0.1 MB   [🗑]
Al-Baqarah     45 MB    [🗑]
[Kelola Download →]
```
- Ganti qari → muncul informasi: "Audio qari baru belum diunduh. Streaming akan digunakan. Unduh untuk offline."
- Jika audio qari baru sudah ada → langsung ganti tanpa download

#### E. Download Manager Page
```
Unduh Murottal
──────────────────
Qari: Misyary Rasyid Al-Afasy

Sudah Diunduh (2 surah, 45.1 MB)
  ✓ Al-Fatihah        0.1 MB   [🗑]
  ✓ Al-Baqarah       45.0 MB   [🗑]

Unduh Surah Lain
  Al-'Imran   [⬇ Unduh]   ~20 MB
  An-Nisa     [⬇ Unduh]   ~25 MB
  ...
```
- Warning untuk surah panjang (> 5 MB atau > 100 ayat):
  "Surah ini cukup panjang (~45 MB). Waktu unduh tergantung kecepatan koneksi."

### 2.5 Architecture

```
lib/Quran/
├── domain/
│   └── entities/
│       ├── qari.dart              # Qari entity (id, name, slug)
│       └── audio_info.dart        # AudioInfo (qariId, url, type, ayatNumber?)
├── data/
│   ├── datasources/
│   │   ├── equran_remote_datasource.dart   # HTTP client equran.id
│   │   └── audio_local_datasource.dart     # Download + storage management
│   └── repositories/
│       └── murottal_repository_impl.dart
├── murottal/
│   ├── application/
│   │   ├── murottal_controller.dart        # ValueNotifier: state player
│   │   ├── audio_player_service.dart       # just_audio wrapper
│   │   ├── download_controller.dart        # ValueNotifier: state download
│   │   └── qari_store.dart                 # SharedPreferences: selected qari
│   └── presentation/
│       ├── widgets/
│       │   ├── mini_player.dart            # Bottom sheet persistent
│       │   └── download_button.dart        # Button download + progress
│       └── pages/
│           └── download_manager_page.dart
```

**State Management:** `ValueNotifier` sesuai konvensi project.

**Dependencies baru:**
```yaml
just_audio: ^0.9.40           # Audio player (stream + offline)
audio_session: ^0.1.21        # Audio session management
just_audio_background: ^0.0.1 # Background audio (P2)
```

**Storage:**
- Audio file: `getApplicationDocumentsDirectory()/murottal/{qariId}/{surahNumber}.mp3`
- Metadata: `SharedPreferences` key `murottal_downloads` (JSON list)
- Selected qari: `SharedPreferences` key `murottal_qari`

---

## 3. Fitur B — Tafsir

### 3.1 User Stories

**US-TF-01: Baca Tafsir Ayat**
Sebagai pengguna, saya ingin membaca tafsir penjelasan sebuah ayat, sehingga saya bisa memahami makna ayat tersebut lebih dalam.

**US-TF-02: Navigasi Antar Ayat dalam Tafsir**
Sebagai pengguna, saya ingin berpindah ke ayat sebelumnya/berikutnya saat membaca tafsir, sehingga saya tidak perlu tutup dan buka ulang.

### 3.2 Keputusan Design

| Aspek | Keputusan | Alasan |
|-------|-----------|--------|
| Letak UI | Bottom Sheet per ayat | Clean, on-demand, tidak ganggu layout utama |
| Trigger | Ikon info (ℹ) di VerseView header, dekat share/play/bookmark | Konsisten dengan ikon aksi lainnya |
| Cache | Hive lokal, TTL 30 hari | Tafsir jarang berubah; hemat bandwidth |
| Rendering | `flutter_html` untuk render HTML dari API | Teks tafsir berisi tag `<i>`, `<b>`, dll |

### 3.3 Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| TF-01 | Ikon info di setiap ayat → buka bottom sheet tafsir | P0 |
| TF-02 | Tampilkan tafsir lengkap per ayat dalam bottom sheet | P0 |
| TF-03 | Navigasi prev/next ayat dalam bottom sheet tafsir | P0 |
| TF-04 | Loading state & error state di bottom sheet tafsir | P0 |
| TF-05 | Cache tafsir lokal (offline setelah load pertama) | P1 |
| TF-06 | Render HTML dari teks tafsir (tag `<i>`, `<b>`, dll) | P1 |

### 3.4 UI Specification

#### A. VerseView — Ikon Info (tambahan)
```
[strip header abu]
  [● badge nomor]  [share] [▶ play] [bookmark] [ℹ tafsir]
                                                    ↑
                                          tap → buka bottom sheet tafsir
```
Urutan ikon di VerseView header: share → play → bookmark → tafsir (ℹ)

#### B. Tafsir Bottom Sheet
```
┌──────────────────────────────────────────┐
│  ──── (drag handle)                      │
│  Tafsir Ayat 1                    [✕]   │
│  ─────────────────────────────────────── │
│                                          │
│  بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ           │
│                                          │
│  Surah al-Fatihah dimulai dengan...     │
│  [teks panjang HTML rendered]           │
│                                          │
│  ─────────────────────────────────────── │
│  [◀ Ayat Sebelumnya]  [Ayat Berikutnya ▶]│
└──────────────────────────────────────────┘
```
- Drag handle di atas untuk dismiss
- Teks Arab ayat di atas teks tafsir
- HTML rendered via `flutter_html`
- Navigasi prev/next ayat tanpa tutup sheet

### 3.5 Architecture

```
lib/Quran/
├── domain/
│   └── entities/
│       └── tafsir.dart                    # Tafsir entity (ayat, teks)
├── data/
│   ├── datasources/
│   │   ├── equran_remote_datasource.dart  # Shared dengan Murottal
│   │   └── tafsir_local_datasource.dart   # Hive cache
│   └── repositories/
│       └── tafsir_repository_impl.dart
└── tafsir/
    ├── application/
    │   └── tafsir_controller.dart          # ValueNotifier: fetch + cache
    └── presentation/
        └── widgets/
            └── tafsir_bottom_sheet.dart    # Bottom sheet UI
```

**Dependencies baru:**
```yaml
flutter_html: ^3.0.0   # Render HTML teks tafsir
dio: ^5.7.0            # HTTP client (sudah ada di project?)
```

**Cache:**
- Hive box `tafsir_cache`, key = surah number (int)
- TTL disimpan di entry: `{data: [...], cachedAt: timestamp}`
- Expired setelah 30 hari → fetch ulang

---

## 4. Shared Infrastructure

### 4.1 equran Remote Data Source

Satu datasource shared untuk Murottal & Tafsir:

```dart
abstract class EquranRemoteDataSource {
  Future<SurahAudioModel> getSurahAudio(int surahNumber);
  Future<TafsirResponseModel> getTafsir(int surahNumber);
}
```

**HTTP client:** `dio` dengan:
- Base URL: `https://equran.id/api/v2`
- Timeout: 15 detik connect, 30 detik receive
- Retry: 2x untuk network error

### 4.2 Connectivity Handling

- Cek koneksi sebelum fetch (gunakan `connectivity_plus` yang sudah ada)
- Offline → gunakan cache jika ada; error jika belum pernah fetch

---

## 5. Milestones & Implementation Phases

### Phase 1 — Shared Infrastructure (prerequisite)

**Deliverables:**
- `EquranRemoteDataSource` (dio HTTP client, model response)
- `QariStore` (SharedPreferences: selected qari)
- Entity `Qari`, `AudioInfo`, `Tafsir`
- `connectivity_plus` wrapper utility

**Tests:** Unit test datasource + mock HTTP response

---

### Phase 2A — Tafsir (paralel dengan 2B)

**Deliverables:**
- `TafsirController` (fetch + Hive cache)
- `TafsirBottomSheet` widget
- Ikon tafsir (ℹ) di `VerseView` header (tambah setelah bookmark)
- Route/trigger dari `SurahDetailPage`

**Tests:** Unit controller + widget test bottom sheet

---

### Phase 2B — Murottal Player (paralel dengan 2A)

**Deliverables:**
- `AudioPlayerService` (just_audio wrapper)
- `MurottalController` (state: idle/loading/playing/paused/error)
- Tombol play per ayat di `VerseView` (ikon play sudah ada, wire ke controller)
- Tombol play full surah di `SurahHeaderCard`
- `MiniPlayer` widget (bottom sheet persistent)

**Tests:** Unit controller + widget test player

---

### Phase 3A — Tafsir Polish

**Deliverables:**
- HTML rendering via `flutter_html`
- Navigasi prev/next ayat dalam bottom sheet
- Loading shimmer + error state
- Cache offline (Hive TTL 30 hari)

---

### Phase 3B — Murottal Download

**Deliverables:**
- `DownloadController` (progress, status per surah)
- Tombol download di `SurahHeaderCard`
- Warning surah panjang sebelum download
- Progress indicator saat download

**Tests:** Unit test download controller

---

### Phase 4 — Settings & Download Manager

**Deliverables:**
- Pilih qari di halaman Settings Quran (dropdown/bottom sheet)
- Informasi ganti qari → perlu download ulang
- Mode player toggle (Inline vs Mini Player)
- `DownloadManagerPage`
- List download + hapus

---

### Phase 5 — Polish & Background Audio (P2)

**Deliverables:**
- Background audio (`just_audio_background`)
- Kontrol kecepatan playback (0.5x–2x)
- Highlight ayat aktif saat mini player berjalan
- Auto-scroll ke ayat yang sedang diputar

---

## 6. Non-Functional Requirements

| ID | Requirement | Target |
|----|-------------|--------|
| MN-01 | Audio stream mulai < 3 detik | CDN equran.id |
| MN-02 | Download tidak blokir UI | Background isolate |
| MN-03 | Cache tafsir < 50ms response (setelah cached) | Hive sync read |
| MN-04 | Tidak ada memory leak dari audio player | Dispose pada widget destroy |
| MN-05 | Test coverage business logic | > 80% |

---

## 7. Constraints

- API equran.id: public, tanpa auth, rate limit tidak diketahui — implement retry + backoff.
- Tidak ada CDN sendiri; semua audio dari cdn.equran.id.
- Storage device terbatas — beri peringatan ukuran sebelum download.
- `just_audio_background` butuh konfigurasi tambahan Android/iOS (P2, bukan P0).
- Bahasa UI: Bahasa Indonesia.

---

## 8. Dependencies Baru

| Package | Versi | Fungsi | Priority |
|---------|-------|--------|----------|
| `just_audio` | `^0.9.40` | Audio player | P0 |
| `audio_session` | `^0.1.21` | Audio session | P0 |
| `flutter_html` | `^3.0.0` | Render HTML tafsir | P1 |
| `just_audio_background` | `^0.0.1` | Background audio | P2 |

> `dio`, `connectivity_plus`, `path_provider`, `hive_ce` sudah ada di project.
