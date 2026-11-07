# Skenario Uji Manual: Quran Semua Usia

Skenario ini untuk uji manual di HP asli. Isinya mencakup fitur dari `PRD_SEMUA_USIA.md` yang sudah dibangun, yaitu Fase 1 (Baca Nyaman) dan Fase 3 (Alat Belajar). Skenario Fase 2 (tasbih, tracker, kalender Hijriah) ditambahkan setelah fiturnya dibangun.

Test otomatis (`flutter test`) sudah lulus. Dokumen ini menguji hal yang tidak terjangkau test otomatis: audio sungguhan, mikrofon, pengenalan suara, layar kecil, pembaca layar, dan kenyamanan pengguna.

## Cara memakai

1. Pasang build dari branch `feat/bl-08-dengar-tirukan`, karena branch itu memuat semua fitur Fase 1 dan Fase 3.
2. Jalankan tiap skenario, lalu isi kolom **Hasil** dengan `Lulus`, `Gagal`, atau `Lewati`.
3. Untuk yang `Gagal`, tulis catatan di bawah tabel: ID skenario, apa yang terjadi, dan tangkapan layar jika ada.

## Perangkat dan kondisi uji

Jalankan semua skenario minimal sekali di kondisi **A**. Skenario bertanda ⭐ diulang juga di kondisi B sampai E.

| Kode | Kondisi |
|---|---|
| A | HP Android biasa, ukuran teks sistem normal, mode terang, ada internet |
| B | HP layar kecil (lebar sekitar 360dp) |
| C | Ukuran teks sistem paling besar (Pengaturan HP → Tampilan → Ukuran font) |
| D | Mode gelap |
| E | TalkBack aktif (pembaca layar) |

Penguji yang disarankan: satu orang lansia dan satu anak, untuk skenario bertanda 👵🧒. Amati apakah mereka bisa menyelesaikan tanpa dibantu.

---

## Fase 1: Baca Nyaman

### BC-01 sampai BC-03: Tampilan ayat dan ukuran teks

Buka **Pengaturan → Tampilan Ayat / Ukuran Teks**.

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BC-01-1 ⭐ | Buka sebuah surah, misalnya Al-Fatihah | Tiap ayat menampilkan teks Arab, latin (miring, warna lebih pudar), dan terjemahan | |
| BC-01-2 | Matikan **Tampilkan latin**, lalu kembali ke surah | Baris latin hilang; Arab dan terjemahan tetap ada | |
| BC-01-3 | Tutup aplikasi sepenuhnya, lalu buka lagi | Latin tetap mati (pilihan diingat) | |
| BC-01-4 | Hidupkan internet mati, buka surah yang belum pernah dibuka | Latin tidak muncul tetapi aplikasi tidak error; Arab dan terjemahan tetap tampil | |
| BC-02-1 | Matikan **Tampilkan terjemahan** | Terjemahan hilang di semua ayat; latin tidak terpengaruh | |
| BC-02-2 | Matikan latin dan terjemahan sekaligus | Hanya teks Arab yang tampil, tanpa ruang kosong yang aneh | |
| BC-03-1 ⭐👵 | Pilih preset **Kecil, Sedang, Besar, Sangat Besar** satu per satu | Preview di halaman Pengaturan langsung berubah; teks Arab, latin, dan terjemahan membesar bersama | |
| BC-03-2 ⭐ | Pilih **Sangat Besar**, buka Al-Baqarah ayat 282 (ayat terpanjang) | Teks tidak terpotong, tidak tumpang tindih, bisa digulir normal | |
| BC-03-3 | Pilih **Besar**, tutup dan buka ulang aplikasi | Preset **Besar** masih terpilih | |

### BC-04: Area sentuh dan label tombol

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BC-04-1 👵🧒 | Di header tiap ayat, ketuk ikon Bagikan, Putar, Simpan, Tafsir | Mudah diketuk tanpa salah tekan ikon sebelahnya | |
| BC-04-2 (kondisi E) | Dengan TalkBack, sentuh tiap ikon di header ayat 5 | TalkBack membaca "Bagikan ayat 5", "Putar ayat 5", "Simpan ayat 5", "Tafsir ayat 5" | |
| BC-04-3 (kondisi E) | Saat ayat diputar, sentuh ikon putar | TalkBack membaca "Hentikan ayat N" | |

### BC-05 dan BC-06: Simpan ayat (bookmark)

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BC-05-1 | Di Al-Baqarah ayat 255, ketuk ikon Simpan | Ikon berubah terisi; muncul snackbar **Ayat disimpan** dengan tombol **Batal** | |
| BC-05-2 | Ulangi BC-05-1, lalu ketuk **Batal** di snackbar | Ikon kembali kosong; ayat tidak ada di daftar simpanan | |
| BC-05-3 | Simpan ayat, lalu ketuk ikon Simpan lagi | Ayat terhapus dari simpanan | |
| BC-05-4 | Simpan 2 ayat, tutup paksa aplikasi, buka lagi | Kedua ayat masih tersimpan | |
| BC-05-5 | Buka aplikasi lalu langsung (dalam 1 detik) simpan ayat | Ayat yang sudah tersimpan sebelumnya tidak hilang | |
| BC-06-1 | Buka halaman simpanan saat belum ada yang disimpan | Muncul pesan "Belum ada ayat yang disimpan…" | |
| BC-06-2 | Simpan Yasin:1, lalu Al-Baqarah:255, lalu buka halaman simpanan | Urutan terbaru di atas: Al-Baqarah:255, lalu Yasin:1 | |
| BC-06-3 | Ketuk Al-Baqarah:255 di daftar | Halaman surah terbuka dan langsung bergulir ke ayat 255 | |
| BC-06-4 | Hapus satu ayat dari halaman simpanan | Ayat hilang dari daftar; ikon di halaman surah juga kosong | |
| BC-06-5 | Simpan beberapa ayat, buat cadangan (backup), hapus data aplikasi, pulihkan cadangan | Ayat simpanan kembali | |
| BC-06-6 | Pulihkan cadangan lama (dibuat sebelum fitur bookmark ada) | Pemulihan berhasil; simpanan yang ada di HP tidak terhapus | |

### BC-07: Bagikan ayat

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BC-07-1 | Ketuk Bagikan di Al-Ikhlas ayat 1, pilih WhatsApp | Lembar bagikan Android muncul; pesan berisi teks Arab, latin, terjemahan, lalu rujukan "QS. Al-Ikhlas: 1" | |
| BC-07-2 | Matikan **Tampilkan latin**, lalu bagikan ayat | Pesan tanpa latin; Arab, terjemahan, dan rujukan tetap ada | |
| BC-07-3 | Matikan **Tampilkan terjemahan**, lalu bagikan ayat | Terjemahan tetap ikut di pesan (bagikan selalu menyertakan terjemahan) | |

### BC-08 dan BC-09: Navigasi dan Yasin

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BC-08-1 ⭐👵 | Lihat menu bawah di halaman utama | Tiap ikon punya label teks yang selalu terlihat, bukan hanya saat dipilih | |
| BC-08-2 (kondisi C) | Lihat menu bawah dengan ukuran teks sistem terbesar | Label tidak terpotong dan tidak keluar dari menu | |
| BC-09-1 👵 | Di halaman utama, ketuk kartu **Buka Surat Yasin** | Surah Yasin (36) terbuka di ayat 1 | |

### NF-01 sampai NF-04: Aksesibilitas umum

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| NF-1 (kondisi B, C) | Gulir daftar surah dan buka 3 surah berbeda | Tidak ada teks terpotong, garis kuning-hitam, atau tombol bertumpuk | |
| NF-2 (kondisi D) | Ulangi NF-1 di mode gelap | Semua teks terbaca jelas; tidak ada teks gelap di atas latar gelap | |
| NF-3 (kondisi E) | Dengan TalkBack, buka surah dan kembali ke halaman utama | Tombol Menu, Kembali, Cari surah, Mode gelap/terang dibacakan dengan nama yang jelas | |

---

## Fase 3: Alat Belajar

Siapkan: pastikan audio murottal bisa diputar (ada internet atau audio sudah diunduh). Uji dengan headset dan tanpa headset.

### BL-01: Kecepatan putar

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BL-01-1 | Putar Al-Fatihah, ketuk tombol kecepatan di mini player beberapa kali | Kecepatan berganti 0.5x → 0.75x → 1x → 1.25x → kembali 0.5x; suara terdengar lebih lambat/cepat | |
| BL-01-2 | Pilih 0.75x, tutup aplikasi, buka lagi, putar ayat | Kecepatan masih 0.75x | |
| BL-01-3 🧒 | Putar di 0.5x | Suara melambat tanpa nada berubah aneh (tidak seperti kaset rusak) | |

### BL-02 sampai BL-04: Ulang dan jeda

Buka pengaturan **Ulang** dari mini player.

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BL-02-1 | Pilih **Satu ayat**, jumlah ulangan 3, tanpa jeda; putar Al-Ikhlas ayat 1 | Ayat 1 diputar 3 kali lalu berhenti | |
| BL-02-2 | Pilih **Satu ayat**, **Ulang terus-menerus** | Ayat terus diulang sampai pengguna menekan berhenti | |
| BL-03-1 | Pilih **Rentang ayat** 2 sampai 4, jumlah ulangan 2; putar surah penuh Al-Ikhlas | Diputar 2, 3, 4, 2, 3, 4 lalu berhenti | |
| BL-03-2 | Rentang ayat akhir lebih besar dari jumlah ayat surah | Tidak error; berhenti di ayat terakhir surah | |
| BL-04-1 | **Satu ayat**, 3 kali, jeda 5 detik | Ada hening sekitar 5 detik di antara tiap ulangan | |
| BL-04-2 | Saat sedang jeda antar ulangan, tekan pause, lalu play | Pemutaran lanjut ke ulangan berikutnya | |
| BL-04-3 | Saat sedang jeda antar ulangan, tekan pause, ubah pengaturan ulang, lalu tekan play | **Diketahui bermasalah:** bisa jadi tidak ada suara. Catat perilakunya | |
| BL-04-4 | Ubah mode ulang ke **Mati**, tutup aplikasi, buka lagi | Pengaturan ulang kembali ke default (memang tidak disimpan) | |

### BL-05 dan BL-06: Daftar Juz

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BL-05-1 | Di halaman utama, ketuk **Juz** pada pilihan Surah/Juz | Daftar 30 juz tampil; item pertama **Juz Amma — surah pendek** (Juz 30), lalu Juz 1 sampai 29 | |
| BL-05-2 | Ketuk Juz 2 | Al-Baqarah terbuka dan bergulir ke ayat 142 | |
| BL-05-3 | Cek acak Juz 15, 23, 30 | Terbuka di Al-Isra:1, Yasin:28, An-Naba:1 | |
| BL-06-1 🧒 | Minta anak mencari surah pendek untuk hafalan | Anak menemukan Juz Amma tanpa dibantu | |
| BL-05-4 (kondisi E) | TalkBack pada item Juz Amma | Terbaca "Juz 30, Juz Amma, surah pendek…" | |

### BL-07: Lanjut otomatis ke surah berikutnya

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BL-07-1 | Pastikan **Lanjut otomatis ke surah berikutnya** aktif (Pengaturan Murottal). Putar surah penuh Al-Ikhlas | Setelah ayat terakhir, Al-Falaq ayat 1 langsung diputar | |
| BL-07-2 | Matikan pengaturan itu, ulangi | Berhenti setelah ayat terakhir Al-Ikhlas | |
| BL-07-3 | Putar satu ayat terakhir saja (bukan surah penuh) dengan pengaturan aktif | Tidak lanjut ke surah berikutnya | |
| BL-07-4 | Putar surah penuh An-Nas (surah terakhir) | Berhenti setelah ayat terakhir; tidak error | |
| BL-07-5 | Mode ulang aktif, lalu putar surah penuh | Mode ulang yang berlaku; tidak lanjut ke surah berikutnya | |
| BL-07-6 | Saat lanjut otomatis berjalan, lihat layar | **Catatan:** halaman tetap di surah lama, tidak ikut pindah. Catat apakah ini membingungkan | |

### BL-08: Dengar lalu Tirukan

Masuk lewat tombol **Dengar lalu Tirukan · {surah}** di halaman Murojaah. Uji dengan surah pendek dulu (misalnya Al-Ikhlas) di ruangan tenang.

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BL-08-1 | Pertama kali membuka mode ini | Izin mikrofon diminta; model pengenalan suara diunduh bila belum ada | |
| BL-08-2 | Tolak izin mikrofon | Muncul **Ada masalah (audio atau mikrofon). Coba lagi.** dan tombol **Mulai lagi**; aplikasi tidak macet | |
| BL-08-3 👵🧒 | Dengarkan ayat 1 sampai selesai | Status **Dengarkan…** saat audio, lalu **Giliranmu, tirukan…** saat mic aktif; teks ayat terlihat terus | |
| BL-08-4 | Tirukan ayat dengan benar | Muncul **Benar! Lanjut**, lalu ayat berikutnya diputar | |
| BL-08-5 | Sengaja baca salah (lewati satu kata) | Muncul **Coba lagi**, lalu ayat yang sama diputar ulang | |
| BL-08-6 | Benar sampai ayat terakhir | Muncul **Selesai**; mic mati | |
| BL-08-7 | Atur jeda 5 detik dan kecepatan 0.75x, lalu ulangi BL-08-3 | Audio pakai 0.75x; ada jeda sekitar 5 detik sebelum mic aktif | |
| BL-08-8 | Tekan **Berhenti** saat audio diputar, lalu saat mic aktif | Audio dan mic langsung mati; status **Dihentikan** | |
| BL-08-9 | Diam saja saat **Giliranmu, tirukan…** | **Diketahui:** tidak ada batas waktu, layar menunggu terus. Catat berapa lama penguji menunggu sebelum bingung | |
| BL-08-10 | Berhenti membaca di tengah ayat | Catat apakah dinilai **Coba lagi** atau menunggu terus | |
| BL-08-11 | Uji tanpa headset (pakai speaker HP) | Suara speaker tidak terhitung sebagai bacaan pengguna | |
| BL-08-12 | Uji dengan headset | Alur berjalan sama seperti tanpa headset | |
| BL-08-13 | Tekan tombol kembali saat mic aktif | Keluar dari halaman; mic dan audio mati (cek ikon mic di status bar) | |

---

## Catatan hasil uji

| ID skenario | Kondisi | Apa yang terjadi | Penguji | Tanggal |
|---|---|---|---|---|
| | | | | |
