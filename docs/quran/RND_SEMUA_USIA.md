# R&D: Aplikasi Quran Nyaman untuk Semua Usia

Tanggal: 7 November 2026
Basis kode: commit `9531cc6` (branch `main`)

## Tujuan

Menilai apakah fitur aplikasi sudah setara dengan aplikasi Quran dan aplikasi ibadah lain.

Aplikasi ditujukan untuk **semua usia**: anak, remaja, dewasa, dan lansia. Lansia dan anak dipakai sebagai **acuan kenyamanan**. Kalau mereka nyaman, pengguna lain juga nyaman.

- **Lansia**: penglihatan menurun, jari kurang presisi, belum tentu terbiasa dengan ikon.
- **Anak dan pemula**: belum lancar membaca huruf Arab, belajar dengan mendengar dan meniru.
- **Remaja dan dewasa**: sudah terbiasa dengan aplikasi modern. Mereka termotivasi oleh streak, target, dan berbagi, dan tidak mau tampilan yang terasa kekanak-kanakan.

Keputusan produk: aplikasi tetap menyediakan fitur ibadah harian (**tasbih, kalender Hijriah, tracker ibadah**), bukan hanya fitur belajar.

## Prinsip desain untuk semua usia

1. **Satu aplikasi, bukan aplikasi terpisah per usia.** Kenyamanan lansia dan anak dicapai lewat pengaturan bawaan yang baik, bukan lewat "mode anak" atau "mode lansia" yang terpisah.
2. **Pengaturan bawaan yang lega.** Huruf besar, tombol besar, dan label teks di menu sejak awal. Pengguna yang ingin tampilan lebih padat bisa memperkecilnya.
3. **Bantuan bisa dimatikan.** Latin, terjemahan, tajwid berwarna, dan audio pelan membantu pemula. Pengguna yang sudah lancar bisa menyembunyikannya.
4. **Ramah, tapi tidak kekanak-kanakan.** Maskot dan ilustrasi dipakai secukupnya, misalnya di layar kosong, perayaan selesai, atau onboarding. Jangan dipasang di setiap layar.
5. **Motivasi yang berlaku di semua usia.** Streak, XP, target harian, dan tracker ibadah memotivasi anak dan remaja, dan tetap berguna bagi dewasa dan lansia.
6. **Pengaturan awal saat pertama kali membuka aplikasi.** Pengguna memilih sendiri ukuran teks dan bantuan yang ditampilkan, tanpa ditanya usianya.

## Metode

- Membaca kode halaman baca, audio, murojaah, progres, pengaturan, dan navigasi. Aplikasi **belum dijalankan** di perangkat.
- Membandingkan dengan aplikasi lain lewat situs resmi, halaman App Store, dan artikel ulasan. **Tidak ada aplikasi pembanding yang dicoba langsung.** Jadi fitur yang tidak disebut di sumber belum tentu tidak ada.
- Aplikasi pembanding: Meowslim, Quran Kemenag, NU Online, Muslim Pro, Tarteel, Quran.com dan Greentech Al Quran, Umma, serta aplikasi belajar mengaji untuk anak.

## Ringkasan

Fondasi aplikasi kuat. Murojaah dengan pengenalan suara **offline dan gratis** adalah pembeda utama. Pesaing terdekatnya, Tarteel, menaruh fitur deteksi kesalahan di paket berbayar.

Ada tiga kelompok kekurangan:

1. **Membaca dan belajar belum ramah untuk lansia dan pemula.** Transliterasi latin tidak tampil padahal datanya ada. Huruf terlalu kecil. Tombol terlalu kecil dan sebagian tidak berfungsi. Audio tidak bisa diperlambat atau diulang.
2. **Fitur ibadah harian belum ada.** Tasbih, kalender Hijriah, tracker ibadah, serta Yasin dan Tahlil sudah menjadi standar di Meowslim, NU Online, Muslim Pro, dan Umma.
3. **Belum ada aplikasi yang benar-benar nyaman untuk lansia.** Dari pencarian, lansia masih banyak membeli mushaf cetak jumbo. Aplikasi yang nyaman untuk lansia dan anak, tapi tetap terasa modern bagi remaja, bisa menjadi pembeda.

## Temuan di kode

| # | Temuan | Lokasi | Dampak |
|---|---|---|---|
| 1 | `Verse.transliteration` sudah dimuat (dan di-prefetch), tetapi `VerseView` hanya merender teks Arab dan terjemahan. | `lib/Quran/presentation/widgets/verse_view.dart` | Pemula yang belum bisa membaca Arab tidak punya pegangan. |
| 2 | Ukuran huruf Arab bawaan 18 (rentang 14–36). Terjemahan bawaan 16 (rentang 12–28). Pengaturannya berupa slider angka. | `lib/Quran/data/font_size_store.dart`, `lib/Quran/presentation/pages/settings_page.dart` | Terlalu kecil untuk lansia. Angka sulit dipahami. |
| 3 | Ikon aksi per ayat berukuran 20px dengan jarak 16px, memakai `GestureDetector` tanpa label semantik. | `verse_view.dart` (`_VerseHeader`) | Di bawah standar sentuh 48×48dp. Mudah salah tekan. |
| 4 | Ikon Share dan Bookmark per ayat tidak punya `onTap`. Tab Bookmark di menu bawah menampilkan "Segera hadir". | `verse_view.dart`, `lib/Quran/presentation/pages/quran_home_page.dart` | Terasa seperti aplikasi rusak. |
| 5 | Menu bawah hanya ikon, tanpa label teks. Ikon lampu dipakai untuk Murojaah. | `quran_home_page.dart` (`_QuranBottomNav`) | Arti menu tidak jelas bagi lansia. |
| 6 | `MurottalController` tidak punya pengaturan kecepatan, ulang ayat, atau ulang rentang ayat. Lanjut otomatis hanya antar ayat dalam satu surah. | `lib/Quran/murottal/application/murottal_controller.dart` | Anak menghafal dengan mendengar berulang. |
| 7 | Tidak ada navigasi Juz sama sekali. | Seluruh `lib/` | Pemula biasanya mulai dari Juz Amma. |
| 8 | Murojaah hanya cocok untuk yang sudah hafal. Belum ada alur "dengar lalu tirukan". | `lib/Quran/murojaah/recite/` | Pemula belum bisa ikut murojaah. |
| 9 | Tidak ada tasbih, kalender Hijriah, atau tracker ibadah. Kata "hijri" tidak ditemukan di kode. | Seluruh `lib/` | Fitur ibadah harian yang standar di aplikasi lain belum ada. |
| 10 | Sudah ada log aktivitas dengan streak, XP, dan level, tetapi `ActivityType` baru mencakup `quranRead`, `murojaah`, `tafsir`, dan `doa`. | `lib/Quran/murojaah/progress/activity_entry.dart`, `progress_service.dart` | Bisa diperluas untuk tracker ibadah tanpa membuat sistem baru. |
| 11 | Dukungan pembaca layar tipis: sekitar 17 pemakaian `Semantics`/`semanticLabel`/`tooltip` di seluruh `lib/`. | Seluruh `lib/` | TalkBack/VoiceOver kurang membantu. |
| 12 | `README.md` dan `ROADMAP.md` tertinggal dari kode. Murottal, Tafsir, Doa, dan Shalat masih tertulis "belum di-wire", padahal sudah terpasang. | `README.md`, `ROADMAP.md` | Dokumentasi menyesatkan. |

## Yang sudah bagus

- Teks Quran dibaca dari aset lokal, jadi bisa tanpa internet. Audio bisa diunduh per surah.
- Murojaah dengan pengenalan suara offline, peta hafalan, dan pengingat murojaah.
- Kontras warna diuji otomatis terhadap WCAG AA (`test/unit/quran_tokens_test.dart`).
- Teks di layar Murojaah sudah ramah, misalnya "Baca dengan suara biasa."
- Sudah ada streak, XP, level, cadangan data, jadwal shalat, arah kiblat, dan doa.
- Ukuran huruf mengikuti pengaturan sistem, karena `textScaler` tidak dibatasi.

## Perbandingan dengan aplikasi lain

### Ringkasan per aplikasi

| Aplikasi | Fokus | Fitur menonjol menurut sumber | Pelajaran untuk aplikasi ini |
|---|---|---|---|
| **Meowslim** | Ibadah harian serba ada, gratis | Bookmark, baca per Juz dan halaman, pintasan Yasin, murottal lanjut otomatis antar surah, tasbih dengan XP dan level, kalender Hijriah dengan hari besar dan puasa sunah, tracker ibadah (shalat, ngaji, dzikir), absen shalat, maskot kucing, sinkronisasi antar perangkat | Tasbih dengan XP, tracker ibadah, kalender Hijriah, Yasin, maskot |
| **Quran Kemenag** (LPMQ Kemenag) | Mushaf resmi Indonesia | Mushaf Standar Indonesia yang ditashih, tajwid berwarna, dua jenis tafsir, murottal beberapa qari, baca per ayat atau per halaman, jadwal shalat, kalender Hijriah | Lansia Indonesia terbiasa dengan Mushaf Standar Indonesia. Sumber teks perlu dicek |
| **NU Online** | Super app warga NU | Yasin dan Tahlil berdampingan, ratusan doa dan wirid, tasbih digital, kalender Hijriah, kiblat, ziarah, kalkulator zakat. Semua konten dilengkapi terjemah dan transliterasi latin | Yasin dan Tahlil untuk lansia. Latin ditampilkan di semua konten |
| **Muslim Pro** | Global, ada paket premium berbayar | Tasbih dengan riwayat, kalender Hijriah, khatam tracker, tracker shalat dan puasa dengan streak, pengaturan ukuran huruf, Quran offline | Khatam tracker, tracker shalat dan puasa |
| **Tarteel** | Hafalan dengan AI | Deteksi kesalahan per kata saat menghafal, pengaturan "jangan lanjut sebelum benar", intip ayat berikutnya saat lupa, paket keluarga untuk 5 anggota. Deteksi kesalahan termasuk fitur Premium | Pesaing terdekat murojaah. Aplikasi ini unggul karena gratis dan offline. Cek apakah sudah ada fitur "intip ayat" |
| **Quran.com / Greentech Al Quran** | Studi Quran | Arti per kata, mode baca terjemahan seperti buku, mode studi (tafsir dan ayat terkait). Greentech gratis dan tanpa iklan | Sumber data arti per kata |
| **Umma** | Komunitas Muslim Indonesia | Mutaba'ah yaumiyah (catatan ibadah harian) dengan poin yang bisa ditukar hadiah, kajian video, kelas daring | Tracker ibadah dengan poin cocok untuk anak |
| **Aplikasi belajar mengaji anak** (misalnya "Belajar Al Qur'an" di iOS, dan beberapa penelitian kampus) | Belajar dari nol | Iqro jilid 1–6 bertahap, suara pada tiap huruf, kuis tebak huruf, rekam dan putar suara sendiri saat menghafal Juz Amma, lagu hijaiyah | Modul hijaiyah, fitur rekam dan putar suara sendiri |
| **Aplikasi khusus lansia** | — | Tidak ditemukan aplikasi yang dirancang khusus untuk lansia. Yang ada aplikasi umum, satu aplikasi untuk gangguan penglihatan, dan mushaf cetak jumbo | Mode lansia bisa menjadi pembeda |

### Posisi aplikasi ini dibanding yang lain

| Fitur | Aplikasi ini | Yang sudah punya (menurut sumber) |
|---|---|---|
| Murojaah dengan deteksi suara | ✅ Gratis dan offline | Tarteel (berbayar) |
| Peta hafalan, pengingat murojaah | ✅ | — |
| Transliterasi latin | ⚠️ Data ada, tidak tampil | NU Online |
| Bookmark | ❌ Ikon tidak berfungsi | Meowslim, Quran.com |
| Navigasi Juz / per halaman | ❌ | Meowslim, Quran Kemenag, NU Online |
| Yasin (dan Tahlil) | ❌ | Meowslim (Yasin), NU Online (Yasin dan Tahlil) |
| Tasbih digital | ❌ | Meowslim, NU Online, Muslim Pro |
| Kalender Hijriah | ❌ | Meowslim, Quran Kemenag, NU Online, Muslim Pro, Umma |
| Tracker ibadah | ❌ (log baru untuk Quran, murojaah, tafsir, doa) | Meowslim, Muslim Pro, Umma |
| Khatam tracker | ❌ | Muslim Pro |
| Tajwid berwarna | ❌ | Quran Kemenag |
| Arti per kata | ❌ | Quran.com, Greentech |
| Kecepatan dan ulang audio | ❌ | iQuran, Bayan |
| Belajar hijaiyah / Iqro | ❌ | Aplikasi belajar mengaji anak |
| Maskot, tampilan ramah anak | ❌ | Meowslim |
| Nyaman untuk lansia (huruf dan tombol besar sejak awal) | ❌ | Belum ada yang ditemukan |

## Rekomendasi prioritas

### P0: perbaikan cepat, dampak besar

1. Tampilkan transliterasi latin di `VerseView`, dengan pengaturan tampil/sembunyi.
2. Perbesar ukuran huruf. Arab: bawaan 28, maksimal 48. Terjemahan: bawaan 18, maksimal 32. Ganti slider angka dengan pilihan Kecil / Sedang / Besar / Sangat Besar.
3. Perbesar area sentuh ikon per ayat menjadi minimal 48×48dp, dan beri label semantik.
4. Sambungkan Bookmark (ikon per ayat dan tab Bookmark). Sambungkan Share, atau sembunyikan sampai siap.
5. Tambahkan label teks di menu bawah.
6. Tambahkan pintasan Yasin di beranda.

### P1a: ibadah harian

7. **Tasbih digital.**
   - Angka hitungan besar dan seluruh layar bisa diketuk, supaya mudah untuk lansia.
   - Getar setiap 33 hitungan, target harian, dan pilihan bacaan (tasbih, tahmid, takbir).
   - Catat ke log aktivitas agar menambah streak dan XP.
8. **Tracker ibadah.**
   - Checklist shalat 5 waktu, tilawah, dzikir, dan puasa.
   - Perluas `ActivityType` dan pakai ulang streak, XP, dan level yang sudah ada, bukan membuat sistem baru.
   - Catatan: `ActivityEntry` saat ini mewajibkan nomor surah dan rentang ayat. Entri doa sudah memakai nomor surah palsu. Entri shalat dan puasa perlu mengikuti pola itu, atau modelnya diubah. Putuskan saat implementasi.
9. **Kalender Hijriah.**
   - Tanggal Hijriah di beranda, penanda hari besar, dan puasa sunah.
   - Tanggal Hijriah di Indonesia ditetapkan lewat sidang isbat, jadi hasil hitungan bisa berbeda satu hari. Sediakan koreksi manual ±1 hari.
10. **Tahlil**, ditempatkan berdampingan dengan Yasin seperti di NU Online.

### P1b: kebutuhan belajar

11. Audio: kecepatan 0.5× / 0.75× / 1× (`just_audio` sudah punya `setSpeed`), ulang satu ayat N kali, dan ulang rentang ayat.
12. Navigasi Juz, dengan Juz Amma paling atas.
13. Mode "Dengar lalu Tirukan" di Murojaah: putar satu ayat, pengguna menirukan, lalu pipeline pengenalan suara yang sudah ada mengecek bacaannya.
14. Murottal lanjut otomatis ke surah berikutnya.
15. Evaluasi sumber teks. Menurut field `meta.source`, `assets/quran/quran.json` berasal dari `api.alquran.cloud` edisi `quran-uthmani`, bukan Mushaf Standar Indonesia. Pertimbangkan memakai Mushaf Standar Indonesia, karena lansia Indonesia terbiasa dengan tanda waqaf dan rasm mushaf ini. File ini juga tidak berisi data juz atau halaman.

### P2: lanjutan

16. Maskot atau ilustrasi ramah, dipakai secukupnya (layar kosong, perayaan selesai, onboarding) supaya tidak terasa kekanak-kanakan bagi remaja dan dewasa.
17. Arti dan audio per kata. equran.id tidak menyediakan data ini. Alternatifnya API quran.com v4, yang punya data per kata dan terjemahan Indonesia.
18. Tajwid berwarna, dengan pilihan untuk mematikannya. Perlu teks beranotasi tajwid, misalnya dari quran.com atau alquran.cloud.
19. Khatam tracker: target khatam dan progres per juz.
20. Pengaturan awal saat pertama kali membuka aplikasi: pilih ukuran teks dan bantuan yang ditampilkan (latin, terjemahan). Tidak menanyakan usia.
21. Pilihan "Tampilan Sederhana" di pengaturan: menu dikurangi menjadi Quran, Murottal, Shalat, dan Tasbih, dengan tombol besar. Ini pilihan untuk siapa saja yang menginginkannya, bukan mode khusus lansia.
22. Bagikan ayat sebagai gambar (kartu ayat) ke media sosial. Fitur ini menarik bagi remaja, dan sekaligus menyelesaikan ikon Share yang belum berfungsi.
23. Modul Hijaiyah/Iqro: suara tiap huruf, latihan bertahap, kuis tebak huruf, serta rekam dan putar suara sendiri. Berguna untuk anak dan juga untuk dewasa atau lansia yang baru belajar membaca. Materi buku Iqro dilindungi hak cipta. Susun materi sendiri, atau minta izin pemegang hak.
24. Perkuat dukungan pembaca layar.
25. Perbarui `README.md` dan `ROADMAP.md` agar sesuai kode.

## Sumber

Meowslim
- [meowslim.id](https://www.meowslim.id/), [meowslim.id/murottal](https://www.meowslim.id/murottal)

Quran Kemenag
- [Quran Kemenag (App Store)](https://apps.apple.com/id/app/quran-kemenag/id1626953037)
- [7 Aplikasi Al-Qur'an Terbaik 2026 (Viva)](https://techno.viva.co.id/platform/28058-7-aplikasi-al-quran-terbaik-2026-mempermudah-ibadah)
- [Ministry of Religion RI Presents Digital-Based Quran Application (Times Indonesia)](https://timesindonesia.co.id/english/192459/ministry-of-religion-ri-presents-digitalbased-quran-application)

NU Online
- [NU Online Super App](https://nu.or.id/superapp)
- [Bacaan Tahlil Lengkap, Akses di Aplikasi Ini](https://nu.or.id/nasional/bacaan-tahlil-lengkap-akses-di-aplikasi-ini-SKxCO)
- [Tasbih Digital NU Online](https://nu.or.id/nasional/tasbih-digital-nu-online-menghitung-dzikir-cara-mudah-dan-kekinian-YSGDX)
- [NU Online: Quran Sholat Tahlil](https://appgoblin.info/apps/id.or.nu.app)

Muslim Pro
- [Muslim Pro (App Store)](https://apple.co/3AsCvox)
- [Muslim Pro (mwm.ai)](https://mwm.ai/apps/muslim-pro-quran-athan/388389451)

Tarteel
- [Tarteel Tutorials: Memorization Mistake Detection](https://tarteel.ai/blog/tarteel-tutorials-memorization-mistake-detection/)
- [Tarteel (App Store)](https://apps.apple.com/it/app/id1391009396)
- [Tarteel AI (similarlabs)](https://similarlabs.com/p/tarteel-ai)

Quran.com dan Greentech
- [Quran.com: New Translation Reading Mode](https://quran.com/product-updates/new-translation-reading-mode-read-like-a-book)
- [Quran.com: New Study Mode](https://ssr.quran.com/explore/new-study-mode-on-quran-com)
- [Al Quran (Tafsir & by Word), Greentech](https://apps.apple.com/gb/app/id1437038111)

Umma
- [Ketika AI Bantu Umat Muslim Beribadah (detikINET)](https://inet.detik.com/mobile-apps/d-4527449/ketika-ai-bantu-umat-muslim-beribadah-lebih-mudah)
- [3 Fitur di Aplikasi Umma (Selular.ID)](https://selular.id/2019/04/3-fitur-di-aplikasi-umma-permudah-muslim-jadi-lebih-baik/)

Aplikasi anak
- [Belajar Al Qur'an (App Store)](https://apps.apple.com/id/app/id1641006974)
- [Belajar Bermain Hijaiyah (App Store)](https://apps.apple.com/np/app/belajar-bermain-hijaiyah/id6736708058)
- [Rancangan Media Pembelajaran Iqra' Berbasis Android (UIN Suska)](https://ejournal.uin-suka.ac.id/index.php/sitekin/article/view/17890)

Lansia
- [Al Quran Standar Indonesia (App Store)](https://apps.apple.com/app/id1562552826)
- [Al-Qur'an Terjemahan Manula (Gramedia)](https://www.gramedia.com/products/al-qur-an-terjemahan-manula)

Fitur audio
- [iQuran (App Store)](https://apps.apple.com/gb/app/id285944183)
- [Bayan - The Noble Quran (App Store)](https://apps.apple.com/app/id1405309156)
- [Al-Quran | Beginner Quran (App Store)](https://apps.apple.com/app/id6474894373)
