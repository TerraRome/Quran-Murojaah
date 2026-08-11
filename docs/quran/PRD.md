# Product Requirements Document — Quran (lib/Quran)

> Standalone showcase module di dalam Flutter Portfolio, sejajar dengan `Sanity` dan `Volta`.

> **Konvensi Wajib**: Setiap plan/pengerjaan WAJIB membaca catatan Second Brain Programming terkait terlebih dahulu (path: `~/Desktop/Projects/Second-Brain-Programming/Mobile Dev/Flutter/`). Daftar per fase ada di section 8. Jangan mulai implementasi sebelum catatan yang relevan dibaca.

## 1. Product Overview

### 1.1 Vision

Menunjukkan kemampuan membangun aplikasi content-reading yang rapi, offline-first, dan scalable — dari data statis yang besar (114 surah) sampai pengalaman membaca yang nyaman. Menjadi bukti kompetensi di sisi data handling, performa list besar, dan UI yang fokus pada readability.

### 1.2 Target Audiens

- **Recruiter / Hiring Manager** — Melihat kemampuan deliver fitur content-heavy yang utuh.
- **Flutter Developer** — Belajar pola data lokal berukuran besar tanpa backend.
- **Technical Interviewer** — Mengevaluasi keputusan arsitektur (offline-first, data source abstraction).
- **Muslim user** — Menggunakan aplikasi untuk membaca Al-Quran.

### 1.3 Success Metrics

| Metric | Target |
|--------|--------|
| Data 114 surah lengkap & akurat | Validasi vs sumber referensi |
| Offline 100% tanpa internet | Semua konten dari aset lokal |
| Startup list surah | < 500 ms (data di-memori / lazy load) |
| Scroll 114 surah | 60 FPS tanpa jank |
| Test coverage business logic | > 80% |
| Code quality | Lolos Flutter Lints tanpa warning |

## 2. Product Requirements

### 2.1 Functional Requirements

| ID | Requirement | Priority | Fase |
|----|-------------|----------|------|
| QR-01 | Tampilkan list 114 surah (nama Arab, latin, arti, jumlah ayat, nomor) | P0 | 1 |
| QR-02 | Buka detail surah berisi semua ayat (Arab + terjemah) | P0 | 1 |
| QR-03 | Data bersumber dari aset lokal (JSON/asset bundle), offline-first | P0 | 1 |
| QR-04 | Loading state & error state (korup/missing asset) yang proper | P0 | 1 |
| QR-05 | Pencarian surah (filter nama latin/arti) | P1 | 3 |
| QR-06 | Navigasi antar surah dari detail (prev/next surah) | P1 | 3 |
| QR-07 | Bookmark / last-read (simpan posisi baca) | P1 | 3 |
| QR-08 | Tampilkan tajwid/audio murottal | P2 | 3 |

### 2.2 Non-Functional Requirements

| ID | Requirement | Target |
|----|-------------|--------|
| QN-01 | Clean Architecture | Domain layer zero framework dependency |
| QN-02 | Offline-first | 100% berfungsi tanpa koneksi |
| QN-03 | Performance | List 114 surah scroll mulus; lazy-load ayat |
| QN-04 | Accessibility | Ayat terbaca screen reader; font scalable |
| QN-05 | Test coverage | > 80% business logic |
| QN-06 | Code quality | Tanpa warning lints |

## 3. User Stories

### US-QR-01: Membaca Surah
Sebagai muslim, saya ingin membuka surah dan membaca ayat Arab beserta terjemahannya, sehingga saya bisa membaca Al-Quran tanpa internet.

### US-QR-02: Mencari Surah
Sebagai pengguna, saya ingin mencari surah berdasarkan nama, sehingga saya cepat menemukan surah yang saya cari.

### US-QR-03: Melanjutkan Bacaan
Sebagai pengguna, saya ingin melanjutkan bacaan dari posisi terakhir, sehingga saya tidak perlu mencari ulang.

## 4. Data Model

### Surah
| Field | Type | Contoh |
|-------|------|--------|
| `number` | int | 1 |
| `name` (Arab) | String | الفاتحة |
| `transliteration` (latin) | String | Al-Fatihah |
| `translation` (arti) | String | Pembukaan |
| `revelationType` | enum | meccan / medinan |
| `totalVerses` | int | 7 |
| `verses` | List<Verse> | ... |

### Verse
| Field | Type | Contoh |
|-------|------|--------|
| `number` (global) | int | 1 |
| `numberInSurah` | int | 1 |
| `arabic` | String | بِسْمِ اللَّهِ ... |
| `translation` | String | Dengan nama Allah ... |

> Data dirender dari aset lokal (bundle `assets/`), bukan dari API.

## 5. Architecture (Modular, mengikuti pola Sanity/Volta)

Berdasarkan catatan **Folder Structure Best Practice** dan **Modular Architecture** (Second Brain 08): project ini memakai **single-module modular (Level 2/3 hybrid)** — fitur dipisah folder per modul di dalam satu package. Modul `Quran` hanya boleh depend ke `core/` (theme, widgets, router), tidak boleh cross-depend ke modul lain.

Per layer (mengikuti **Clean Architecture** — dependensi dari luar ke dalam, domain zero-framework):

```
lib/Quran/
├── domain/                  # Contract + entity murni (tanpa framework)
│   ├── entities/            #   surah.dart, verse.dart  (class immutable const biasa, tanpa codegen)
│   ├── repositories/        #   quran_repository.dart   (abstract)
│   └── failures/            #   quran_failure.dart      (sealed class)
├── data/                    # Implementasi + data source
│   ├── datasources/         #   quran_asset_datasource.dart  (loader JSON aset + cache)
│   └── repositories/        #   quran_repository_impl.dart
├── application/             # State sederhana (self-contained)
│   └── quran_controller.dart  # ValueNotifier / StatefulWidget
└── presentation/            # Pages & widgets
    ├── pages/
    │   ├── surah_list_page.dart
    │   └── surah_detail_page.dart
    └── widgets/
        ├── surah_card.dart
        ├── verse_view.dart
        └── ...
```

Konvensi yang dipegang (selaras catatan Second Brain + pola Sanity/Volta existing):
- **Repository Pattern**: UI/bloc hanya bicara ke `QuranRepository` abstrak; implementasi asset lokal mudah diganti API di masa depan tanpa sentuh UI.
- **Entity vs Model**: `domain/entities/` murni Dart tanpa `fromJson`; serialization hanya di `data/datasources/`.
- **Model tanpa freezed**: mengikuti keputusan project (lihat Project Log) — class immutable const biasa, self-contained tanpa codegen.
- **State**: cukup `ValueNotifier`/`StatefulWidget` untuk skala ini; upgrade ke Bloc hanya jika kompleksitas bertambah (State Management MOC).

### Alur Data

```
UI (ListPage) → QuranController → QuranRepository(abstrak) → QuranRepositoryImpl → QuranAssetDataSource (JSON aset + cache)
                (state)               ↑ domain contract            ↓ data layer         (parse DTO → entity)
```

Integrasi ke app:
- Route baru di `lib/core/router/app_router.dart` → `/home/quran`, `/home/quran/:surahNumber`
- Entry card baru di `lib/features/home/presentation/pages/home_page.dart`
- Tidak menambah dependency baru (data JSON di `assets/`)

## 6. Technical Stack

| Layer | Technology |
|-------|-----------|
| Data source | Aset lokal (JSON di `assets/`), di-decode & cache di memori |
| State | StatefulWidget / ValueNotifier sederhana (self-contained) |
| Routing | go_router (existing) |
| UI | Material 3 + design tokens |
| Testing | flutter_test + mocktail (data loader) |

## 7. Constraints

- Module di dalam repo yang sama (`lib/Quran`), bukan package terpisah.
- Tidak ada backend/API — data offline dari aset lokal.
- Bahasa Indonesia untuk dokumentasi; English untuk kode/komentar.
- Tidak menambah dependency baru tanpa diskusi.

## 8. Milestones

> Setiap fase WAJIB diawali dengan membaca catatan Second Brain yang tercantum di kolom **Baca Second Brain**.

| Fase | Deliverables | Baca Second Brain |
|------|--------------|-------------------|
| 0. Review konvensi | Konfirmasi struktur & konvensi project | `08-Architecture-Patterns/{Architecture Patterns MOC, Folder Structure Best Practice, Clean Architecture, Repository Pattern, Modular Architecture}.md` |
| 1. Data & Fondasi | Model surah/ayat, aset JSON 114 surah, data source + cache, repository (abstrak + impl), route & entry card | `07-Local-Storage-Database/File IO.md`, `08-Architecture-Patterns/Repository Pattern.md`, `14-Tools-DevOps/Code Generation (build_runner).md` (alasan tanpa freezed) |
| 2. UI Baca | List surah (performant, `.builder()`), detail surah (ayat + terjemah), loading/error state | `03-Widgets/Scrolling Widgets dan ListView.md`, `03-Widgets/StreamBuilder & FutureBuilder.md`, `11-Performance-Optimization/Rebuild Optimization & Const.md` |
| 3. Polish | Search (debounce), prev/next surah, bookmark/last-read | `04-State-Management/{State Management MOC, Local State vs Global State}.md`, `07-Local-Storage-Database/{SharedPreferences, Local Storage MOC}.md` |
| 4. QA | Unit test data loader & repository, widget test, verifikasi emulator | `10-Testing/{Unit Test, Widget Test, Mocking}.md`, `16-Project-Log/Project Log MOC.md` |

**Catatan lintas fase** (baca kapan pun relevan):
- `16-Project-Log/2026-07-31 - Flutter-Portfolio.md` — konvensi project & keputusan teknis terbaru.
- `00-MOC/Package Versions.md` — tracker versi package agar tidak ada dependency baru yang tidak perlu.

## 9. Referensi Data

- Struktur data mengikuti skema umum API Al-Quran (equran.id / api.alquran.cloud) agar mudah dimigrasi ke API di masa depan.
- Nama/arti surah validasi silang dengan sumber tepercaya sebelum final.
