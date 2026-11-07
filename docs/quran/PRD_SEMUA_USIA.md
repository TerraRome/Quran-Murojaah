# PRD — Quran Nyaman untuk Semua Usia

> Dasar dokumen ini: [RND_SEMUA_USIA.md](RND_SEMUA_USIA.md) (temuan kode dan perbandingan dengan aplikasi lain).
> Basis kode: commit `9531cc6` (branch `main`).

## 1. Product Overview

### 1.1 Visi

Aplikasi Quran dan ibadah harian yang nyaman untuk semua usia. Lansia dan anak dipakai sebagai acuan kenyamanan, dan aplikasi tetap terasa modern bagi remaja dan dewasa.

Pembeda utama aplikasi ini adalah murojaah dengan pengenalan suara yang **gratis dan offline**. Fitur itu sudah ada. Dokumen ini menutup celah lainnya: kenyamanan membaca, ibadah harian, dan alat belajar.

### 1.2 Target pengguna

| Persona | Ciri | Kebutuhan utama |
|---|---|---|
| **Lansia** | Penglihatan menurun, jari kurang presisi, tidak terbiasa dengan ikon | Huruf dan tombol besar, menu berlabel, Yasin dan Tahlil, tasbih |
| **Anak dan pemula** | Belum lancar membaca huruf Arab, belajar dengan mendengar dan meniru | Latin, audio pelan dan berulang, Juz Amma, latihan menirukan |
| **Remaja** | Terbiasa dengan aplikasi modern, termotivasi oleh streak dan berbagi | Streak, XP, tracker ibadah, bagikan ayat, tampilan tidak kekanak-kanakan |
| **Dewasa** | Rutinitas ibadah harian, waktu terbatas | Jadwal shalat, tracker, bookmark, lanjut baca |

### 1.3 Prinsip desain

1. **Satu aplikasi untuk semua usia.** Tidak ada mode anak atau mode lansia yang terpisah.
2. **Pengaturan bawaan yang lega.** Huruf besar, tombol besar, dan label teks di menu sejak awal.
3. **Bantuan bisa dimatikan.** Latin, terjemahan, dan audio pelan bisa disembunyikan oleh pengguna yang sudah lancar.
4. **Ramah, tapi tidak kekanak-kanakan.** Ilustrasi dipakai secukupnya.
5. **Motivasi untuk semua usia.** Streak, XP, dan target harian.
6. **Tidak pernah menanyakan usia.** Pengguna memilih tampilan, bukan kategori umur.

### 1.4 Ukuran keberhasilan

| Metrik | Target | Cara ukur |
|---|---|---|
| Area sentuh | Semua elemen yang bisa diketuk ≥ 48×48dp | Widget test `androidTapTargetGuideline` dan `iOSTapTargetGuideline` di halaman utama |
| Label tombol | Semua tombol punya label | Widget test `labeledTapTargetGuideline` |
| Kontras | WCAG AA | `test/unit/quran_tokens_test.dart` (sudah ada) dan `textContrastGuideline` |
| Skala teks sistem | Tidak ada overflow pada skala teks 2.0× | Widget test halaman utama dengan `TextScaler.linear(2.0)` |
| Uji kegunaan | 3 lansia, 3 anak, dan 3 remaja menyelesaikan 4 tugas tanpa dibantu | Tugas: buka Yasin, ulang satu ayat 3×, hitung tasbih 33×, centang shalat Subuh |
| Offline | Semua fitur di dokumen ini berjalan tanpa internet, kecuali unduh audio | Uji manual dalam mode pesawat |

## 2. Ruang Lingkup

### 2.1 Termasuk

- **Kenyamanan baca** (P0): latin, ukuran huruf, area sentuh, bookmark, bagikan ayat, label menu, pintasan Yasin.
- **Ibadah harian** (P1): tasbih, tracker ibadah, kalender Hijriah, Tahlil, serta penataan ulang menu bawah.
- **Alat belajar** (P1): kecepatan audio, ulang ayat, navigasi Juz, lanjut otomatis antar surah, mode "Dengar lalu Tirukan".
- **Lanjutan** (P2): daftar fitur di bagian 3.4. Masing-masing akan dirinci di PRD tersendiri sebelum dikerjakan.

### 2.2 Tidak termasuk

- Akun pengguna dan sinkronisasi ke server. Cadangan tetap memakai ekspor manual yang sudah ada.
- Asmaul Husna, kalkulator zakat, ziarah, dan kajian video.
- Penggantian sumber teks Quran. Ini masih keputusan terbuka (Q-05).
- Qari baru, tema warna baru, desain ulang halaman yang tidak disebut di dokumen ini, dan bahasa selain Indonesia.
- Notifikasi baru. Yang berlaku hanya pengingat dan adzan yang sudah ada.
- Perubahan model, threshold, atau logika pencocokan pengenalan suara.

### 2.3 Batas per fitur

Fitur dianggap selesai saat kriteria di bagian 3 terpenuhi. Tabel ini mencatat hal yang **tidak** dikerjakan, walaupun terlihat sebagai kelanjutan wajar.

| Fitur | Yang dikerjakan | Yang tidak dikerjakan |
|---|---|---|
| Latin (BC-01) | Tampilkan dan sembunyikan | Pilihan gaya transliterasi, latin per kata, mengedit teks latin |
| Ukuran teks (BC-03) | 4 pilihan ukuran | Pilihan jenis huruf, jarak baris, ukuran per elemen |
| Bookmark (BC-05, BC-06) | Simpan ayat, daftar, hapus | Folder, kategori, catatan, warna, bookmark doa |
| Bagikan (BC-07) | Bagikan sebagai teks | Kartu gambar (LN-01), pilihan format |
| Menu bawah (BC-08, IB-15) | Label dan susunan baru, maksimal 5 tab | Menu yang bisa diatur pengguna |
| Yasin (BC-09) | Pintasan ke surah 36 | Tampilan baca khusus untuk Yasin |
| Tasbih (IB-01 sampai IB-05) | Satu hitungan aktif, 6 bacaan, target | Bacaan buatan pengguna, riwayat per sesi, statistik dzikir |
| Tracker (IB-06 sampai IB-10) | 8 item tetap, ringkasan 7 hari | Ibadah buatan pengguna, grafik bulanan, qadha shalat, pengingat |
| Kalender (IB-11 sampai IB-13) | Tanggal, hari besar, puasa sunah, koreksi | Acara buatan pengguna, notifikasi hari besar, jadwal imsakiyah |
| Tahlil (IB-14) | Satu susunan, teks saja | Audio Tahlil, pilihan susunan dari tradisi lain |
| Audio (BL-01 sampai BL-04, BL-07) | Kecepatan, ulang, jeda, lanjut otomatis antar surah | Pengatur waktu tidur, equalizer, unduh massal |
| Juz (BL-05, BL-06) | Daftar 30 juz | Navigasi per halaman, hizb, atau rub' (datanya tidak ada) |
| Dengar lalu Tirukan (BL-08) | Alur putar, rekam, cocokkan, dengan pipeline yang ada | Penilaian tajwid, skor baru, perubahan pengenalan suara |

### 2.4 Aturan menjaga scope

1. Kerjakan hanya requirement yang punya ID di dokumen ini.
2. Ide baru selama pengerjaan dicatat di bagian 11 (Parkir). Ide itu tidak dikerjakan di fase yang sedang berjalan.
3. Menambah requirement atau mengubah kriteria selesai harus lewat perubahan PRD ini dulu, dan disetujui pemilik produk.
4. Fase berikutnya baru dimulai setelah semua kriteria fase sebelumnya terpenuhi. Pengecualiannya fase 2 dan 3, yang boleh paralel.
5. Fitur P2 (LN-xx) tidak dikerjakan sebelum PRD tersendirinya disetujui.
6. Ubah hanya file yang dibutuhkan oleh requirement. Refactor di luar itu dicatat sebagai temuan, tidak dikerjakan.
7. Dependensi baru wajib didiskusikan dulu.
8. Setiap commit dan PR menyebut ID requirement yang dikerjakan, misalnya `BC-05`.
9. Setiap fitur dikerjakan di branch baru yang dibuat dari `main` terbaru (`git pull` dulu). Setelah selesai, branch di-push, di-merge ke `main`, lalu `main` di-push. Contoh nama branch: `feat/bc-05-bookmark`, `docs/prd-semua-usia`.

## 3. Functional Requirements

### 3.1 Kenyamanan Baca — P0

| ID | Requirement | Kriteria selesai |
|---|---|---|
| BC-01 | Transliterasi latin tampil di bawah teks Arab pada setiap ayat. | `VerseView` merender `Verse.transliteration`. Pengaturan "Tampilkan latin" bawaannya **aktif**. Jika latin surah belum tersedia, baris latin disembunyikan tanpa pesan error (lihat Q-08). |
| BC-02 | Pengaturan "Tampilkan terjemahan". | Bawaannya aktif. Jika dimatikan, terjemahan tersembunyi di semua halaman baca. |
| BC-03 | Ukuran teks dipilih lewat 4 pilihan, bukan slider angka. | Pilihan dan ukurannya mengikuti tabel 5.1. Bawaannya **Sedang**. Pengguna yang sudah menyimpan ukuran lama tetap memakai ukuran itu sampai memilih ulang. |
| BC-04 | Semua ikon aksi di ayat (putar, bookmark, bagikan, tafsir) punya area sentuh ≥ 48×48dp dan label semantik. | Contoh label: "Putar ayat 5", "Simpan ayat 5". Lolos `androidTapTargetGuideline` dan `labeledTapTargetGuideline`. |
| BC-05 | Bookmark ayat. | Ketuk ikon untuk menyimpan atau membatalkan. Muncul snackbar "Ayat disimpan" dengan tombol "Batal". Ikon terisi jika ayat sudah disimpan. |
| BC-06 | Halaman Bookmark menampilkan daftar ayat yang disimpan. | Urut dari yang terbaru. Tiap baris berisi nama surah, nomor ayat, dan potongan terjemahan. Ketuk untuk membuka surah dan menggulir ke ayat itu. Ayat bisa dihapus dari daftar. Ada tampilan kosong yang menjelaskan cara menyimpan ayat. Teks "Segera hadir" dihapus. |
| BC-07 | Bagikan ayat sebagai teks. | Isi: teks Arab, latin (jika aktif), terjemahan, dan rujukan "QS. Al-Baqarah: 255". Memakai `share_plus` yang sudah terpasang. |
| BC-08 | Menu bawah menampilkan label teks di bawah ikon. | Label selalu tampil, tidak hanya di tab aktif. Ukuran label minimal 12sp. |
| BC-09 | Pintasan Yasin di tab Quran. | Kartu "Surat Yasin" di dekat kartu Terakhir Dibaca. Ketuk untuk membuka surah 36. |

### 3.2 Ibadah Harian — P1

| ID | Requirement | Kriteria selesai |
|---|---|---|
| IB-01 | Tasbih digital. | Seluruh area tengah layar bisa diketuk untuk menambah hitungan. Angka hitungan berukuran minimal 72sp. |
| IB-02 | Pilihan bacaan tasbih. | Subhanallah, Alhamdulillah, Allahu Akbar, Laa ilaaha illallah, Astaghfirullah, dan Shalawat. Masing-masing tampil dalam Arab, latin, dan arti. |
| IB-03 | Target dan getar. | Target 33, 99, 100, atau angka sendiri. Getar ringan di setiap ketukan, getar kuat setiap kelipatan 33 dan saat target tercapai. Getar bisa dimatikan. |
| IB-04 | Hitungan tidak hilang. | Hitungan tersimpan saat aplikasi ditutup. Tombol reset meminta konfirmasi. |
| IB-05 | Tasbih tercatat di log aktivitas. | Saat target tercapai atau sesi diakhiri, satu entri `dzikir` dicatat sehingga streak dan XP bertambah. |
| IB-06 | Tracker ibadah harian. | Checklist per hari: Subuh, Dzuhur, Ashar, Maghrib, Isya, Tilawah, Dzikir, dan Puasa. |
| IB-07 | Sebagian isian tracker terisi otomatis. | Tilawah tercentang jika ada entri `quranRead` atau `murojaah` hari itu. Dzikir tercentang jika ada entri `dzikir`. Shalat dan Puasa diisi manual. |
| IB-08 | Puasa hanya ditampilkan di hari yang relevan. | Muncul pada Ramadan, hari puasa sunah (lihat IB-12), atau jika pengguna menambahkannya sendiri. |
| IB-09 | Isian tracker bisa diubah sampai 7 hari ke belakang. | Untuk pengguna yang lupa mencentang. Lebih dari 7 hari hanya bisa dilihat. |
| IB-10 | Ringkasan mingguan tracker. | Tampilan 7 hari dengan jumlah ibadah yang tercentang per hari. |
| IB-11 | Tanggal Hijriah tampil di beranda. | Contoh: "15 Jumadil Awal 1448 H". |
| IB-12 | Halaman kalender bulanan. | Menampilkan tanggal Masehi dan Hijriah. Hari besar ditandai: 1 Muharram, Asyura, Maulid Nabi, Isra Mi'raj, Nisfu Sya'ban, 1 Ramadan, Idul Fitri, Arafah, dan Idul Adha. Puasa sunah juga ditandai: Senin–Kamis, Ayyamul Bidh (13–15), Tasu'a–Asyura, Arafah, dan 6 hari Syawal. |
| IB-13 | Koreksi tanggal Hijriah. | Pengaturan −1, 0, atau +1 hari. Bawaannya 0. Ada keterangan bahwa tanggal resmi ditetapkan pemerintah lewat sidang isbat. |
| IB-14 | Yasin dan Tahlil. | Satu halaman dengan dua tab, Yasin dan Tahlil. Tab Yasin memakai tampilan baca surah 36. Tab Tahlil menampilkan urutan bacaan dalam Arab, latin, dan arti, beserta jumlah ulangan tiap bacaan. |
| IB-15 | Penataan ulang menu bawah. | Lihat 5.2. |

### 3.3 Alat Belajar — P1

| ID | Requirement | Kriteria selesai |
|---|---|---|
| BL-01 | Kecepatan audio. | Pilihan 0.5×, 0.75×, 1×, dan 1.25×. Bisa diubah dari mini player. Pilihan terakhir diingat. |
| BL-02 | Ulang satu ayat. | Pilihan 1×, 3×, 5×, 10×, atau terus-menerus. |
| BL-03 | Ulang rentang ayat. | Pengguna memilih ayat awal dan akhir, lalu jumlah ulangan rentangnya. |
| BL-04 | Jeda antar ulangan. | Pilihan 0, 2, atau 5 detik, supaya pengguna sempat menirukan. |
| BL-05 | Navigasi Juz. | Daftar surah punya dua tab, "Surah" dan "Juz". Ketuk juz untuk membuka surah dan ayat awalnya. |
| BL-06 | Pintasan Juz Amma. | Di tab Juz, Juz 30 tampil paling atas dengan label "Juz Amma — surah pendek". |
| BL-07 | Lanjut otomatis ke surah berikutnya. | Saat memutar satu surah penuh, audio lanjut ke surah berikutnya. Pengaturan ini bawaannya aktif dan bisa dimatikan. |
| BL-08 | Mode "Dengar lalu Tirukan" di Murojaah. | Aplikasi memutar satu ayat (memakai BL-01 dan BL-04), lalu mikrofon aktif. Pengguna menirukan, dan bacaannya dicek oleh pipeline pengenalan suara yang sudah ada. Jika benar, lanjut ke ayat berikutnya. Jika salah, ayat diputar ulang. Ayat tetap terlihat selama mode ini. |

### 3.4 Lanjutan — P2 (dirinci di PRD tersendiri)

| ID | Fitur |
|---|---|
| LN-01 | Bagikan ayat sebagai kartu gambar |
| LN-02 | Maskot atau ilustrasi ramah (layar kosong, perayaan, onboarding) |
| LN-03 | Arti dan audio per kata |
| LN-04 | Tajwid berwarna yang bisa dimatikan |
| LN-05 | Khatam tracker (target khatam dan progres per juz) |
| LN-06 | Pengaturan awal saat pertama kali membuka aplikasi |
| LN-07 | Pilihan "Tampilan Sederhana" |
| LN-08 | Modul Hijaiyah |
| LN-09 | Pemeriksaan pembaca layar menyeluruh |
| LN-10 | Tombol "Sudah shalat" di notifikasi adzan, yang mengisi tracker |

## 4. User Stories

- **US-01 (Lansia):** Sebagai lansia, saya ingin huruf Quran langsung besar saat aplikasi pertama dibuka, sehingga saya tidak perlu mencari pengaturan.
- **US-02 (Lansia):** Sebagai lansia, saya ingin membuka Yasin dan Tahlil dengan sekali ketuk, sehingga saya bisa ikut Yasinan dari ponsel.
- **US-03 (Lansia):** Sebagai lansia, saya ingin menghitung dzikir dengan mengetuk layar di mana saja dan merasakan getaran tiap 33 hitungan, sehingga saya tidak perlu melihat layar terus-menerus.
- **US-04 (Anak):** Sebagai anak, saya ingin membaca latin di bawah ayat, sehingga saya bisa ikut membaca walau belum lancar huruf Arab.
- **US-05 (Anak):** Sebagai anak yang menghafal Juz Amma, saya ingin satu ayat diputar pelan dan berulang dengan jeda, sehingga saya sempat menirukan.
- **US-06 (Anak):** Sebagai anak, saya ingin aplikasi mendengarkan saya menirukan ayat dan memberi tahu kalau sudah benar, sehingga saya bisa berlatih tanpa ditemani.
- **US-07 (Remaja):** Sebagai remaja, saya ingin melihat streak dan centang ibadah harian saya, sehingga saya termotivasi untuk konsisten.
- **US-08 (Remaja):** Sebagai remaja, saya ingin membagikan ayat ke teman, sehingga saya bisa berbagi ayat yang menyentuh saya.
- **US-09 (Dewasa):** Sebagai pengguna, saya ingin menyimpan ayat dan membukanya lagi dari halaman Bookmark, sehingga saya mudah kembali ke ayat favorit.
- **US-10 (Semua):** Sebagai pengguna, saya ingin melihat tanggal Hijriah dan pengingat puasa sunah, sehingga saya tidak melewatkannya.

## 5. Spesifikasi UI

### 5.1 Ukuran teks (BC-03)

| Pilihan | Arab | Latin | Terjemahan |
|---|---|---|---|
| Kecil | 22 | 14 | 14 |
| **Sedang (bawaan)** | 28 | 16 | 18 |
| Besar | 36 | 20 | 22 |
| Sangat Besar | 44 | 24 | 26 |

- Ukuran ini adalah ukuran dasar. Skala teks dari pengaturan sistem tetap berlaku di atasnya.
- Latin memakai gaya miring dengan warna `textMuted` supaya berbeda dari terjemahan.
- Halaman pengaturan menampilkan pratinjau satu ayat lengkap: Arab, latin, dan terjemahan.

### 5.2 Menu bawah (IB-15)

Usulan, menunggu keputusan Q-01:

| Tab | Isi |
|---|---|
| **Quran** | Daftar Surah/Juz, Terakhir Dibaca, pintasan Yasin |
| **Hafalan** | Murojaah, peta hafalan, mode "Dengar lalu Tirukan" |
| **Ibadah** | Jadwal shalat di atas, lalu tracker hari ini, tasbih, kalender, dan kiblat |
| **Doa** | Doa harian, Yasin & Tahlil |
| **Simpan** | Bookmark |

- Tanggal Hijriah (IB-11) tampil di bagian sapaan beranda.
- Ikon lampu untuk Murojaah diganti dengan ikon yang lebih jelas maknanya.

### 5.3 Tasbih (IB-01 sampai IB-05)

- Bagian atas: bacaan terpilih dalam Arab, latin, dan arti.
- Bagian tengah: angka besar dan cincin progres menuju target. Seluruh area ini bisa diketuk.
- Bagian bawah: tombol pilih bacaan, target, dan reset.
- Layar tidak boleh mati selama halaman tasbih terbuka.

### 5.4 Kontrol audio (BL-01 sampai BL-04)

- Mini player mendapat tombol kecepatan (menampilkan "1×") dan tombol ulang.
- Tombol ulang membuka bottom sheet berisi jumlah ulangan, rentang ayat, dan jeda.
- Ayat yang sedang diputar tetap diberi sorotan seperti sekarang.

## 6. Catatan Teknis

Konvensi project tetap berlaku: `ValueNotifier`, state class manual tanpa freezed, injeksi manual lewat konstruktor, dan offline-first.

| Area | Rencana | Kode yang dipakai ulang |
|---|---|---|
| Latin (BC-01) | Teks latin **tidak ada di `quran.json`**. `TransliterationPrefetchService` mengunduhnya dari equran.id saat aplikasi pertama dibuka, lalu menyimpannya di SharedPreferences. Pengguna yang baru memasang aplikasi tanpa internet belum punya latin. | `TransliterationPrefetchService`, `TransliterationLocalDataSource` |
| Pengaturan tampilan (BC-01 sampai BC-03) | Tambah `showLatin`, `showTranslation`, dan ukuran latin ke store dan scope tema. Pilihan ukuran menulis angka ukuran ke key yang sudah ada, jadi data lama tetap terbaca. | `FontSizeStore`, `QuranThemeScope`, `SettingsPage` |
| Bookmark (BC-05, BC-06) | `BookmarkStore` baru di SharedPreferences: daftar `{surah, ayat, waktu}`. Bookmark ikut dimasukkan ke cadangan. | `LastReadStore` (pola), `BackupDocument` |
| Bagikan (BC-07) | Panggil `share_plus` dengan teks yang dirangkai. | `share_plus`, `BackupSharer` (pola) |
| Tasbih dan tracker (IB-01 sampai IB-10) | Tambah nilai `ActivityType` baru: `dzikir`, `shalat`, `puasa`. Nilai `wire` baru tidak boleh mengubah yang lama. Tentukan batas XP harian per jenis baru di `ProgressService`. | `ActivityEntry`, `ActivityStore`, `ProgressService`, `MurojaahWeekCalendar` |
| Kalender Hijriah (IB-11 sampai IB-13) | Konversi Masehi ke Hijriah, ditambah nilai koreksi. Daftar hari besar dan puasa sunah disimpan sebagai tabel konstanta. | — |
| Tahlil (IB-14) | Aset JSON baru `assets/doa/tahlil.json` (Arab, latin, arti, jumlah ulangan). | Pola `DoaLocalDataSource` |
| Juz (BL-05, BL-06) | Tabel konstanta 30 juz (surah dan ayat awal). `quran.json` tidak berisi data juz. | `SurahDetailPage` (gulir ke ayat) |
| Audio (BL-01 sampai BL-04, BL-07) | `setSpeed` dari `just_audio`. Logika ulang dan jeda di controller. Lanjut otomatis ke surah berikutnya di `_onCompleted`. | `MurottalController`, `MiniPlayer` |
| Dengar lalu Tirukan (BL-08) | Alur baru: putar ayat, tunggu selesai, rekam, lalu cocokkan. | `MurottalController`, `ReciteSessionController`, pipeline pengenalan suara |
| Getar dan layar menyala (IB-03, 5.3) | `HapticFeedback` bawaan Flutter untuk getar. Layar menyala perlu dicek apakah butuh paket baru (lihat Q-04). | — |

Struktur folder fitur baru mengikuti pola yang sudah ada: `lib/Quran/<fitur>/{application,data,domain,presentation}`. Usulan nama folder: `tasbih`, `tracker`, `kalender`, dan `bookmark`.

## 7. Non-Functional Requirements

| ID | Requirement | Target |
|---|---|---|
| NF-01 | Area sentuh | ≥ 48×48dp untuk semua elemen yang bisa diketuk |
| NF-02 | Label semantik | Semua tombol ikon punya label dalam bahasa Indonesia |
| NF-03 | Kontras | WCAG AA (teks ≥ 4.5:1, grafik ≥ 3:1), di mode terang dan gelap |
| NF-04 | Skala teks | Tidak ada overflow sampai skala teks sistem 2.0× |
| NF-05 | Offline | Semua fitur di dokumen ini berjalan tanpa internet, kecuali unduh audio |
| NF-06 | Kompatibilitas data | Data streak, XP, dan pengaturan pengguna lama tetap terbaca setelah update |
| NF-07 | Bahasa | Bahasa Indonesia sehari-hari. Hindari istilah teknis seperti "sync" atau "error" di layar |
| NF-08 | Test | Unit test untuk logika baru (konversi Hijriah, ulang audio, tracker otomatis, bookmark). Widget test untuk NF-01 sampai NF-04 di halaman utama |

## 8. Milestones

| Fase | Isi | Selesai jika |
|---|---|---|
| 1. Kenyamanan Baca | BC-01 sampai BC-09 | Semua kriteria di 3.1 terpenuhi, NF-01 sampai NF-04 lolos di halaman Quran dan detail surah |
| 2. Ibadah Harian | IB-01 sampai IB-15 | Tasbih, tracker, kalender, dan Yasin & Tahlil bisa dipakai. Menu bawah sudah ditata ulang. Konten Tahlil sudah ditinjau (Q-03) |
| 3. Alat Belajar | BL-01 sampai BL-08 | Semua kriteria di 3.3 terpenuhi. "Dengar lalu Tirukan" diuji di perangkat asli |
| 4. Uji Kegunaan | Uji dengan 3 lansia, 3 anak, dan 3 remaja | Keempat tugas di 1.4 selesai tanpa dibantu. Temuan dicatat sebagai perbaikan |
| 5. Lanjutan | LN-01 sampai LN-10 | Dirinci di PRD tersendiri |

Fase 2 dan 3 tidak saling bergantung dan bisa dikerjakan paralel. Pengecualiannya BL-08, yang butuh BL-01 dan BL-04.

## 9. Keputusan Terbuka

| ID | Pertanyaan | Rekomendasi |
|---|---|---|
| Q-01 | Apakah susunan menu bawah di 5.2 disetujui? | Setujui. Shalat masuk ke tab Ibadah supaya tasbih, tracker, dan kalender punya tempat |
| Q-02 | Konversi Hijriah: tulis sendiri (algoritma Umm al-Qura atau tabular) atau pakai paket? | Tulis sendiri dengan algoritma tabular ditambah koreksi ±1 hari. Logikanya kecil dan tidak menambah dependensi |
| Q-03 | Sumber teks Tahlil? Susunannya berbeda antar tradisi. | Pakai satu susunan baku yang umum dipakai, lalu minta ustadz meninjaunya sebelum rilis |
| Q-04 | Layar tetap menyala di halaman tasbih butuh paket baru (misalnya `wakelock_plus`)? | Cek dulu. Jika butuh paket, diskusikan sesuai aturan "tidak menambah dependensi tanpa diskusi" |
| Q-05 | Ganti sumber teks ke Mushaf Standar Indonesia? | Riset lisensi dan ketersediaan datanya dulu. Penggantian teks memengaruhi pencocokan murojaah, jadi perlu PRD terpisah |
| Q-06 | Tanggal Hijriah berganti saat Maghrib atau tengah malam? | Tengah malam, mengikuti tanggal Masehi seperti aplikasi lain. Lebih mudah dipahami |
| Q-07 | Apakah tab Murojaah diganti namanya menjadi "Hafalan"? | Ya. "Hafalan" lebih dikenal oleh anak dan lansia |
| Q-08 | Apakah teks latin dimasukkan ke aset supaya tersedia offline sejak pemasangan pertama? | Ya, jika lisensi equran.id mengizinkan. Latin adalah fitur P0, dan NF-05 menuntut offline. Ukuran aset bertambah, jadi cek dulu besarnya |

## 10. Constraints

- Tidak menambah dependensi baru tanpa diskusi.
- Tidak mengubah keputusan teknis di `ROADMAP.md` (ValueNotifier, tanpa freezed, tanpa framework DI, threshold pencocokan).
- Nilai `wire` pada `ActivityType` yang sudah ada tidak boleh diubah.
- Dokumentasi dalam bahasa Indonesia. Kode dan komentar mengikuti gaya file yang sudah ada.

## 11. Parkir

Ide yang muncul selama pengerjaan dicatat di sini dan tidak dikerjakan di fase berjalan. Ide ditinjau setelah fase 4 selesai.

| Tanggal | Ide | Diusulkan oleh | Alasan ditunda |
|---|---|---|---|
| | | | |
