# Plan — Quran Module (`lib/Quran`)

> Dokumen perencanaan & arah pengerjaan. PRD lengkap ada di [`PRD.md`](./PRD.md), checklist eksekusi di [`TASKS.md`](./TASKS.md).
> Konvensi: WAJIB baca Second Brain sebelum tiap fase (daftar di PRD section 8).

## 1. Tujuan

Menghadirkan modul baca Al-Quran offline-first yang **utuh secara UI/UX** —
bukan hanya fungsional. Prioritas saat ini: **merapikan dan memoles UI** sesuai
layout Figma "Quran App Concept", sebelum menambah fitur lain.

## 2. Status Fase

| Fase | Deliverables | Status |
|------|--------------|--------|
| 0 | Review konvensi & struktur | ✅ Selesai |
| 1 | Data & fondasi (model, aset 114 surah, datasource, repository, route, entry card) | ✅ Selesai |
| 2 | UI baca (list surah, detail ayat, loading/error state) | ✅ Core selesai |
| 3 | Polish (search, prev/next, last-read) | 🟡 Sebagian (bookmark belum) |
| 4 | QA (unit/widget test, verifikasi emulator) | 🟡 Sebagian (analyze + verifikasi emulator selesai; test belum) |
| **5** | **Polish UI (fokus sekarang)** | 🔵 Aktif |

## 3. Fase 5 — Polish UI (Aktif)

> Tujuan: menyamakan detail visual dengan Figma, menghilangkan improvisasi,
> dan membuat pengalaman baca terasa premium. **Belum menambah fitur baru.**

### 3.1 Aset & Font
- [ ] Ambil aset SVG asli dari Figma (ikon ilustrasi splash, badge, dst.) —
      ganti improvisasi (`Icon`/`Container` gradien) dengan SVG resmi.
- [ ] Evaluasi Amiri vs GoogleFonts `amiri`: cek loading flash di teks Arab;
      opsi bundle font lokal di `assets/fonts/` bila perlu.
- [ ] Buat state preload font agar teks Arab tidak "lompat" saat halaman dibuka.

### 3.2 Halaman Home
- [ ] Ikon menu di top bar: wiring ke drawer/menu (saat ini `onPressed: () {}`).
- [ ] Perbaiki layout kartu Last Read (spacing, typography, arah navigasi).
- [ ] Tab Para/Page/Hijb: beri konten dasar atau empty state yang rapi
      (jangan tampil seperti tab kosong).
- [ ] Skeleton/shimmer loading untuk list 114 surah (pakai `shimmer` yang sudah
      ada di pubspec), bukan spinner polos.
- [ ] Empty state pencarian yang lebih baik (ikon + pesan).
- [ ] Detail spacing/typography greeting sesuai Figma.

### 3.3 Halaman Detail
- [ ] Scroll list kembali ke atas saat pindah surah (prev/next).
- [ ] Haluskan tampilan `VerseView`: alignment badge nomor ayat, line-height,
      margin antar ayat, konsistensi light/dark.
- [ ] Perbaiki tampilan navigasi prev/next (alignment, ukuran, disabled state).
- [ ] Transisi animasi antar surah (pakai `flutter_animate` yang sudah ada).
- [ ] Load seluruh ayat lebih halus (tidak terasa berat saat scroll).

### 3.4 Konsistensi Global
- [ ] Pastikan splash juga punya toggle dark/light yang konsisten.
- [ ] Audit hardcoded warna di presentation → pindah ke `QuranTokens`.
- [ ] Status bar (brightness) sesuai tema aktif di tiap halaman.
- [ ] SafeArea + bottom padding konsisten di semua halaman.

## 4. Fase 3 lanjutan (backlog, setelah polish UI)

- [ ] Bookmark per-ayat (bookmark icon di verse, list bookmark).
- [ ] Integrasi last-read + bookmark (posisi baca lanjut dari bookmark).

## 5. Fase 4 — QA (setelah polish UI)

- [ ] Unit test: `QuranAssetDataSource` (load + cache + korup JSON), `QuranRepositoryImpl`.
- [ ] Widget test: splash, home list, detail, search, theme toggle.
- [ ] Verifikasi emulator akhir + golden test jika memungkinkan.

## 6. Out of Scope (Fase ini)

- Audio murottal / tajwid (QR-08, P2).
- Sinkronisasi progress antar device (offline-only).
- Mengganti data aset dengan API live.

## 7. Referensi

- Second Brain: `08-Architecture-Patterns`, `07-Local-Storage-Database`,
  `03-Widgets`, `11-Performance-Optimization`, `16-Project-Log`.
- Figma: "Quran App Concept - Free (Community)" (key `Yt0SDawZq88QBXq4yvHuvT`).
