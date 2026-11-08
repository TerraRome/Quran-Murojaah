# Skenario Uji Manual: Quran Semua Usia

Skenario ini untuk uji manual di HP asli. Isinya mencakup fitur dari `PRD_SEMUA_USIA.md` yang sudah dibangun, yaitu Fase 1 (Kenyamanan Baca) dan Fase 3 (Alat Belajar), ditambah kebutuhan non-fungsional (NF) yang bisa diuji sekarang. Skenario Fase 2 (tasbih, tracker, kalender Hijriah, Yasin & Tahlil) ditambahkan setelah fiturnya dibangun.

Test otomatis (`flutter test`) sudah lulus. Dokumen ini menguji hal yang tidak terjangkau test otomatis: audio sungguhan, mikrofon, pengenalan suara, layar kecil, pembaca layar, mode pesawat, update dari versi lama, dan kenyamanan pengguna.

## Cara memakai

1. Pasang build dari branch `main`, karena semua fitur Fase 1 dan Fase 3 sudah di sana.
2. Jalankan tiap skenario, lalu isi kolom **Hasil** dengan `Lulus`, `Gagal`, atau `Lewati`.
3. Untuk yang `Gagal`, tulis catatan di tabel paling bawah: ID skenario, kondisi, apa yang terjadi, dan tangkapan layar jika ada.
4. Skenario bertanda **(diketahui)** menguji masalah yang sudah diketahui. Tujuannya mencatat perilaku nyata di HP, bukan mencari lulus.

## Perangkat dan kondisi uji

Jalankan semua skenario minimal sekali di kondisi **A**. Skenario bertanda ⭐ diulang juga di kondisi B sampai E.

| Kode | Kondisi |
|---|---|
| A | HP Android biasa, ukuran teks sistem normal, mode terang, ada internet |
| B | HP layar kecil (lebar sekitar 360dp) |
| C | Ukuran teks sistem paling besar (Pengaturan HP → Tampilan → Ukuran font) |
| D | Mode gelap |
| E | TalkBack aktif (pembaca layar) |
| F | Mode pesawat (tanpa internet) |

Penguji yang disarankan: satu orang lansia dan satu anak untuk skenario bertanda 👵🧒. Amati apakah mereka bisa menyelesaikan tanpa dibantu.

## Syarat selesai fase (PRD §8)

| Fase | Syarat yang diuji di dokumen ini |
|---|---|
| 1. Kenyamanan Baca | Semua skenario BC dan NF-1 sampai NF-3 lulus |
| 3. Alat Belajar | Semua skenario BL lulus. **BL-08 wajib diuji di HP asli**; ini syarat resmi Fase 3 yang belum terpenuhi |

---

## Fase 1: Kenyamanan Baca

### BC-01 sampai BC-03: Tampilan ayat dan ukuran teks

Buka **Pengaturan → Tampilan Ayat / Ukuran Teks**.

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BC-01-1 ⭐ | Buka sebuah surah, misalnya Al-Fatihah | Tiap ayat menampilkan teks Arab, latin (miring, warna lebih pudar), dan terjemahan | Lulus |
| BC-01-2 | Matikan **Tampilkan latin**, lalu kembali ke surah | Baris latin hilang; Arab dan terjemahan tetap ada | Lulus |
| BC-01-3 | Tutup aplikasi sepenuhnya, lalu buka lagi | Latin tetap mati (pilihan diingat) | Lulus |
| BC-01-4 (kondisi F) | Pasang aplikasi baru dalam mode pesawat, lalu buka sebuah surah | Latin tidak muncul, tanpa pesan error; Arab dan terjemahan tetap tampil. **(diketahui)** latin baru ada setelah pernah online, menunggu Q-08 | Lewati: Marionette tidak bisa pasang ulang aplikasi atau menyalakan mode pesawat |
| BC-01-5 | Setelah BC-01-4, nyalakan internet, tutup dan buka aplikasi, buka surah lagi | Latin muncul | Lewati: bergantung pada BC-01-4 |
| BC-02-1 | Matikan **Tampilkan terjemahan** | Terjemahan hilang di semua ayat; latin tidak terpengaruh | Lulus |
| BC-02-2 | Matikan latin dan terjemahan sekaligus | Hanya teks Arab yang tampil, tanpa ruang kosong yang aneh | Lulus |
| BC-03-1 👵 | Pasang aplikasi baru, buka surah tanpa mengubah pengaturan | Huruf langsung cukup besar (preset **Sedang** terpilih di Pengaturan) | Lewati: aplikasi sudah pernah dipakai, bukan pasang baru |
| BC-03-2 ⭐👵 | Pilih preset **Kecil, Sedang, Besar, Sangat Besar** satu per satu | Preview (Arab, latin, terjemahan) langsung berubah; ketiganya membesar bersama | Lulus |
| BC-03-3 ⭐ | Pilih **Sangat Besar**, buka Al-Baqarah ayat 282 (ayat terpanjang) | Teks tidak terpotong, tidak tumpang tindih, bisa digulir normal | Gagal: lompat ke ayat jauh berhenti di ayat 38, ayat 282 tidak tercapai (lihat catatan) |
| BC-03-4 | Pilih **Besar**, tutup dan buka ulang aplikasi | Preset **Besar** masih terpilih | Lulus |
| BC-03-5 | Di versi lama aplikasi (lihat NF-06), atur ukuran huruf dengan slider ke angka yang tidak umum. Update ke build baru | Ukuran huruf sama seperti sebelum update; tidak ada preset yang terpilih sampai pengguna memilih | Lewati: butuh build versi lama, tidak tersedia |

### BC-04: Area sentuh dan label tombol

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BC-04-1 👵🧒 | Di header tiap ayat, ketuk ikon Bagikan, Putar, Simpan, Tafsir | Mudah diketuk tanpa salah tekan ikon sebelahnya | Lulus |
| BC-04-2 (kondisi E) | Dengan TalkBack, sentuh tiap ikon di header ayat 5 | TalkBack membaca "Bagikan ayat 5", "Putar ayat 5", "Simpan ayat 5", "Tafsir ayat 5" | Lulus, label saja: suara TalkBack belum didengar (lihat catatan) |
| BC-04-3 (kondisi E) | Saat ayat diputar, sentuh ikon putar | TalkBack membaca "Hentikan ayat N" | Lulus, label saja: suara TalkBack belum didengar (lihat catatan) |

### BC-05 dan BC-06: Simpan ayat (Bookmark)

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BC-05-1 | Di Al-Baqarah ayat 255, ketuk ikon Simpan | Ikon berubah terisi; muncul snackbar **Ayat disimpan** dengan tombol **Batal** | Lulus, di ayat 96 (lihat catatan) |
| BC-05-2 | Ulangi BC-05-1, lalu ketuk **Batal** di snackbar | Ikon kembali kosong; ayat tidak ada di tab **Bookmark** | Lulus, di ayat 96 |
| BC-05-3 | Simpan ayat, lalu ketuk ikon Simpan lagi | Ayat terhapus dari simpanan | Lulus |
| BC-05-4 | Simpan 2 ayat, tutup paksa aplikasi, buka lagi | Kedua ayat masih tersimpan | Lulus, pakai hot restart (lihat catatan) |
| BC-05-5 | Buka aplikasi lalu langsung (dalam 1 detik) simpan ayat | Ayat yang sudah tersimpan sebelumnya tidak hilang | Lewati, tertutup unit test (lihat catatan) |
| BC-06-1 | Buka tab **Bookmark** saat belum ada yang disimpan | Muncul pesan "Belum ada ayat yang disimpan…" yang menjelaskan cara menyimpan; tidak ada teks "Segera hadir" | Lulus |
| BC-06-2 | Simpan Yasin:1, lalu Al-Baqarah:255, lalu buka tab **Bookmark** | Urutan terbaru di atas: Al-Baqarah:255, lalu Yasin:1 | Lulus, Al-Baqarah:96 pengganti 255 |
| BC-06-3 | Lihat satu baris di daftar | Berisi nama surah, nomor ayat, dan potongan terjemahan | Lulus |
| BC-06-4 | Ketuk Al-Baqarah:255 di daftar | Halaman surah terbuka dan langsung bergulir ke ayat 255 | Gagal, berhenti di ayat 72 (lihat catatan) |
| BC-06-5 | Hapus satu ayat dari tab **Bookmark** | Ayat hilang dari daftar; ikon di halaman surah juga kosong | Lulus |
| BC-06-6 | Simpan beberapa ayat, buat cadangan (backup), hapus data aplikasi, pulihkan cadangan | Ayat simpanan kembali | Lewati, tertutup unit test (lihat catatan) |
| BC-06-7 | Pulihkan cadangan lama (dibuat sebelum fitur bookmark ada) | Pemulihan berhasil; simpanan yang ada di HP tidak terhapus | Lewati, tertutup unit test (lihat catatan) |

### BC-07: Bagikan ayat

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BC-07-1 | Ketuk Bagikan di Al-Ikhlas ayat 1, pilih WhatsApp | Lembar bagikan Android muncul; pesan berisi teks Arab, latin, terjemahan, lalu rujukan "QS. Al-Ikhlas: 1" | Lulus, via Salin, WhatsApp tidak terpasang (lihat catatan) |
| BC-07-2 | Matikan **Tampilkan latin**, lalu bagikan ayat | Pesan tanpa latin; Arab, terjemahan, dan rujukan tetap ada | Lulus |
| BC-07-3 | Matikan **Tampilkan terjemahan**, lalu bagikan ayat | Terjemahan tetap ikut di pesan (bagikan selalu menyertakan terjemahan) | Lulus |

### BC-08 dan BC-09: Menu bawah dan Yasin

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BC-08-1 ⭐👵 | Lihat menu bawah di halaman utama | Lima tab berlabel **Quran, Murojaah, Shalat, Doa, Bookmark**; label selalu terlihat, bukan hanya di tab aktif | Lulus |
| BC-08-2 (kondisi C) | Lihat menu bawah dengan ukuran teks sistem terbesar | Label tidak terpotong dan tidak keluar dari menu | Gagal, label Murojaah dan Bookmark terpotong (lihat catatan) |
| BC-09-1 👵 | Di tab Quran, cari kartu **Surat Yasin** di bawah kartu Last Read, lalu ketuk | Surah Yasin (36) terbuka di ayat 1 | Lulus |

### NF-01 sampai NF-04: Aksesibilitas umum

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| NF-1 (kondisi B, C) | Gulir daftar surah dan buka 3 surah berbeda | Tidak ada teks terpotong, garis kuning-hitam, atau tombol bertumpuk | Gagal: nomor surah 3 digit dan label menu bawah terpotong saat huruf besar (lihat catatan) |
| NF-2 (kondisi D) | Ulangi NF-1 di mode gelap | Semua teks terbaca jelas; tidak ada teks gelap di atas latar gelap | Lulus |
| NF-3 (kondisi E) | Dengan TalkBack, buka surah dan kembali ke halaman utama | Tombol Menu, Kembali, Cari surah, Mode gelap/terang dibacakan dengan nama yang jelas | Lulus, label saja: suara TalkBack belum didengar (lihat catatan) |

---

## Fase 3: Alat Belajar

Siapkan: unduh dulu audio surah yang dipakai uji (Al-Fatihah, Al-Ikhlas, Al-Falaq, An-Nas). Murottal hanya diputar dari file di HP (lihat NF-08). Uji dengan headset dan tanpa headset.

### BL-01: Kecepatan putar

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BL-01-1 | Putar Al-Fatihah, lihat mini player | Ada tombol kecepatan bertuliskan **1×** | Lulus |
| BL-01-2 | Ketuk tombol kecepatan beberapa kali | Berganti 0.5× → 0.75× → 1× → 1.25× → kembali 0.5×; suara terdengar lebih lambat/cepat | Lulus, label saja: perubahan suara belum didengar (lihat catatan) |
| BL-01-3 | Pilih 0.75×, tutup aplikasi, buka lagi, putar ayat | Kecepatan masih 0.75× | Lewati: tutup dan buka aplikasi belum bisa diuji; 0.75 sudah tersimpan (lihat catatan) |
| BL-01-4 🧒 | Putar di 0.5× | Suara melambat tanpa nada berubah aneh | Lewati: perlu didengar langsung di HP |

### BL-02 sampai BL-04: Ulang dan jeda

Buka pengaturan **Ulang** dari mini player.

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BL-02-1 | Pilih **Satu ayat**, jumlah ulangan 3, tanpa jeda; putar Al-Ikhlas ayat 1 | Ayat 1 diputar 3 kali lalu berhenti | Lulus (lihat catatan) |
| BL-02-2 | Pilih **Satu ayat**, **Ulang terus-menerus** | Ayat terus diulang sampai pengguna menekan berhenti | Lulus (lihat catatan) |
| BL-02-3 | Cek pilihan jumlah ulangan | Tersedia 1×, 3×, 5×, 10×, dan terus-menerus | Lulus |
| BL-03-1 | Pilih **Rentang ayat** 2 sampai 4, jumlah ulangan 2; putar surah penuh Al-Ikhlas | Diputar 2, 3, 4, 2, 3, 4 lalu berhenti | Lulus: diuji dengan 3× karena pilihan 2× tidak ada (lihat catatan) |
| BL-03-2 | Rentang ayat akhir lebih besar dari jumlah ayat surah | Tidak error; berhenti di ayat terakhir surah | Lewati: pilihan ayat akhir dibatasi sampai jumlah ayat surah, jadi kondisi ini tidak bisa dibuat dari UI (lihat catatan) |
| BL-04-1 | **Satu ayat**, 3 kali, jeda 5 detik | Ada hening sekitar 5 detik di antara tiap ulangan | Lulus (lihat catatan) |
| BL-04-2 | Cek pilihan jeda | Tersedia tanpa jeda, 2 detik, dan 5 detik | Lulus |
| BL-04-3 | Saat sedang jeda antar ulangan, tekan pause, lalu play | Pemutaran lanjut ke ulangan berikutnya | Lulus (lihat catatan) |
| BL-04-4 | Saat sedang jeda antar ulangan, tekan pause, ubah pengaturan ulang, lalu tekan play | **(diketahui)** bisa jadi tidak ada suara. Catat perilakunya; ini bug yang akan diperbaiki | Gagal: bug diketahui terbukti; ikon berubah ke pause tapi posisi diam di akhir ayat dan tidak ada suara (lihat catatan) |
| BL-04-5 | Ubah mode ulang, tutup aplikasi, buka lagi | Mode, jumlah, dan jeda ulang tetap seperti terakhir. Rentang ayat tidak disimpan: mode **Rentang** kembali ke **Mati** | Lewati: tutup dan buka aplikasi belum bisa diuji (lihat catatan) |
| BL-04-6 👵🧒 | Minta penguji mengulang satu ayat 3 kali tanpa dibantu | Penguji menemukan tombol ulang dan berhasil (tugas uji kegunaan PRD §1.4) | Lewati: perlu penguji manusia |

### BL-05 dan BL-06: Daftar Juz

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BL-05-1 | Di halaman utama, ketuk **Juz** pada pilihan Surah/Juz | Daftar 30 juz tampil; item pertama **Juz Amma — surah pendek** (Juz 30), lalu Juz 1 sampai 29 | Lulus (lihat catatan) |
| BL-05-2 | Ketuk Juz 2 | Al-Baqarah terbuka dan bergulir ke ayat 142 | Gagal: berhenti di ayat 71, bukan 142 (lihat catatan) |
| BL-05-3 | Cek acak Juz 15, 23, 30 | Terbuka di Al-Isra:1, Yasin:28, An-Naba:1 | Lulus (lihat catatan) |
| BL-05-4 (kondisi E) | TalkBack pada item Juz Amma | Terbaca "Juz 30, Juz Amma, surah pendek…" | Lulus, label saja: suara TalkBack belum didengar (lihat catatan) |
| BL-06-1 🧒 | Minta anak mencari surah pendek untuk hafalan | Anak menemukan Juz Amma tanpa dibantu | Lewati: perlu penguji manusia |

### BL-07: Lanjut otomatis ke surah berikutnya

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BL-07-1 | Pasang aplikasi baru, buka Pengaturan Murottal | **Lanjut otomatis ke surah berikutnya** sudah aktif | Lulus (lihat catatan) |
| BL-07-2 | Putar surah penuh Al-Ikhlas | Setelah ayat terakhir, Al-Falaq ayat 1 langsung diputar | Lulus |
| BL-07-3 | Matikan pengaturan itu, ulangi | Berhenti setelah ayat terakhir Al-Ikhlas | Lulus |
| BL-07-4 | Putar satu ayat terakhir saja (bukan surah penuh) dengan pengaturan aktif | Tidak lanjut ke surah berikutnya | Lulus |
| BL-07-5 | Putar surah penuh An-Nas (surah terakhir) | Berhenti setelah ayat terakhir; tidak error | Lulus (lihat catatan: file unduhan tidak dipakai) |
| BL-07-6 | Mode ulang aktif, lalu putar surah penuh | Mode ulang yang berlaku; tidak lanjut ke surah berikutnya | Lulus |
| BL-07-7 | Saat lanjut otomatis berjalan, lihat layar | Halaman ikut pindah ke surah yang sedang diputar dan menggulir ke ayatnya | Sesuai yang diketahui; membingungkan (lihat catatan) |

### BL-08: Dengar lalu Tirukan (wajib di HP asli)

Masuk lewat tombol **Dengar lalu Tirukan · {surah}** di tab Murojaah. Tombol membuka surah yang terakhir dilatih, atau Al-Fatihah jika belum pernah. Uji dengan surah pendek dulu, di ruangan tenang.

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| BL-08-1 | Pertama kali membuka mode ini | Izin mikrofon diminta; model pengenalan suara diunduh bila belum ada | Gagal: unduhan model gagal karena URL model di paket `recite_quran` 1.0.5 kini HTTP 504 (repo pindah). Spinner sekitar 1 menit tanpa progres, lalu pesan masalah. Izin mikrofon tidak diminta (lihat catatan) |
| BL-08-2 | Tolak izin mikrofon | Muncul **Ada masalah (audio atau mikrofon). Coba lagi.** dan tombol **Mulai lagi**; aplikasi tidak macet | Lewati: terblokir BL-08-1 |
| BL-08-3 👵🧒 | Dengarkan ayat 1 sampai selesai | Status **Dengarkan…** saat audio, lalu **Giliranmu, tirukan…** saat mic aktif; teks ayat terlihat terus | Lewati: terblokir BL-08-1 |
| BL-08-4 | Tirukan ayat dengan benar | Muncul **Benar! Lanjut**, lalu ayat berikutnya diputar | Lewati: terblokir BL-08-1 |
| BL-08-5 | Sengaja baca salah (lewati satu kata) | Muncul **Coba lagi**, lalu ayat yang sama diputar ulang | Lewati: terblokir BL-08-1 |
| BL-08-6 | Benar sampai ayat terakhir | Muncul **Selesai**; mic mati | Lewati: terblokir BL-08-1 |
| BL-08-7 | Atur jeda 5 detik dan kecepatan 0.75× di murottal, lalu ulangi BL-08-3 | Audio pakai 0.75×; ada jeda sekitar 5 detik sebelum mic aktif | Lewati: terblokir BL-08-1 (lihat catatan) |
| BL-08-8 | Tekan **Berhenti** saat audio diputar, lalu saat mic aktif | Audio dan mic langsung mati; status **Dihentikan** | Sebagian lulus: saat audio, status **Dihentikan** dan tidak ada player aktif. Saat mic aktif terblokir BL-08-1 |
| BL-08-9 | Diam saja saat **Giliranmu, tirukan…** | **(diketahui)** tidak ada batas waktu, layar menunggu terus. Catat berapa lama penguji menunggu sebelum bingung | Lewati: terblokir BL-08-1 |
| BL-08-10 | Berhenti membaca di tengah ayat | Catat apakah dinilai **Coba lagi** atau menunggu terus | Lewati: terblokir BL-08-1 |
| BL-08-11 | Uji tanpa headset (pakai speaker HP) | Suara speaker tidak terhitung sebagai bacaan pengguna | Lewati: terblokir BL-08-1 |
| BL-08-12 | Uji dengan headset | Alur berjalan sama seperti tanpa headset | Lewati: terblokir BL-08-1 |
| BL-08-13 | Tekan tombol kembali saat mic aktif | Keluar dari halaman; mic dan audio mati (cek ikon mic di status bar) | Sebagian lulus: kembali saat audio diputar menutup halaman dan audio mati. Saat mic aktif terblokir BL-08-1 |
| BL-08-14 (kondisi F) | Mode pesawat, audio surah belum diunduh | Muncul ajakan unduh surah dengan tombol **Unduh**; alur tidak mulai; aplikasi tidak macet | Belum diuji. Ekspektasi diubah karena murottal kini hanya offline (lihat NF-8-11) |
| BL-08-15 🧒 | Minta anak berlatih 3 ayat sendiri | Anak paham kapan mendengar dan kapan giliran membaca tanpa dijelaskan | Lewati: perlu penguji manusia |

---

## Kebutuhan non-fungsional lain

### NF-05: Offline (kondisi F)

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| NF-5-1 | Mode pesawat (setelah pernah online sekali). Buka surah, ubah ukuran teks, simpan ayat, buka tab Bookmark, buka tab Juz | Semua berjalan normal | Lulus untuk offline. Juz 4 terbuka di ayat yang salah, tapi itu bug lompat ayat (BC-06-4), bukan masalah offline |
| NF-5-2 | Mode pesawat, putar ayat yang audionya sudah diunduh, pakai kecepatan dan ulang | Berjalan normal | Belum diuji ulang. Sebelumnya gagal karena file unduhan tidak dipakai; kini diperbaiki (lihat NF-08) |
| NF-5-3 | Mode pesawat, putar ayat yang audionya belum diunduh | Muncul **Surah ini belum diunduh.** dengan tombol **Unduh**; audio tidak diputar; aplikasi tidak macet | Belum diuji ulang. Ekspektasi diubah karena murottal kini hanya offline |

### NF-06: Data lama tetap ada setelah update

Pasang versi lama dari commit `9531cc6` (sebelum fitur PRD ini), pakai beberapa hari, lalu pasang build baru di atasnya tanpa menghapus data.

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| NF-6-1 | Lihat streak, XP, dan peta hafalan setelah update | Nilainya sama seperti sebelum update | Lewati: butuh build versi lama |
| NF-6-2 | Lihat pengingat, qari terpilih, dan Last Read | Tidak berubah | Lewati: butuh build versi lama |
| NF-6-3 | Lihat ukuran huruf | Lihat BC-03-5 | Lewati: butuh build versi lama |

### NF-07: Bahasa di layar

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| NF-7-1 (kondisi F) | Putar ulang ayat (BL-02) saat audio gagal dimuat | **(diketahui)** pesan bisa memuat teks teknis setelah "Gagal memuat audio:". Catat isi pesannya | Pesan: **Gagal memuat audio: (0) Source error** |
| NF-7-2 | Telusuri semua layar yang diuji di dokumen ini | Tidak ada kata seperti "error", "sync", "null", atau kode teknis. Catat jika ada | Gagal: 6 tempat di kode bisa menampilkan teks teknis (lihat catatan) |

### NF-08: Murottal offline (unduh per surah)

Murottal kini hanya diputar dari file di HP, tidak ada pemutaran online. Pengguna memilih satu surah, lalu aplikasi mengunduh semua file ayatnya (4 file sekaligus). Siapkan: Wi-Fi, data seluler, dan satu surah panjang (Al-Baqarah, sekitar 111 MB untuk qari Afasy).

| ID | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| NF-8-1 | Pasang baru. Buka Al-Fatihah, tekan putar ayat 1 | Muncul **Surah ini belum diunduh.** dengan perkiraan ukuran dan tombol **Unduh**. Tidak ada suara | |
| NF-8-2 | Di dialog itu tekan **Unduh** (Wi-Fi) | Progres berjalan per ayat sampai selesai; tombol di kepala surah berubah jadi status sudah diunduh | |
| NF-8-3 ⭐ (kondisi F) | Mode pesawat. Putar Al-Fatihah per ayat dan surah penuh; coba 0.75×, ulang 3× jeda 5 detik, sebelum/berikutnya | Semua berjalan normal tanpa pesan gagal; ada **Jeda… N** saat jeda | |
| NF-8-4 (kondisi F) | Tutup aplikasi sepenuhnya (hapus dari daftar aplikasi terbaru), nyalakan mode pesawat, buka lagi, putar Al-Fatihah | Audio langsung diputar; tidak butuh internet sama sekali | |
| NF-8-5 | Unduh Al-Baqarah. Di tengah unduhan, matikan internet | Muncul pesan gagal yang mudah dipahami, tanpa teks teknis | |
| NF-8-6 | Nyalakan internet lagi, tekan **Unduh** Al-Baqarah lagi | Progres langsung mulai dari ayat yang sudah ada, bukan dari 0 | |
| NF-8-7 | Saat mengunduh, tekan **Batalkan** | Dialog tertutup tanpa pesan error; unduh lagi melanjutkan dari ayat terakhir | |
| NF-8-8 | Matikan Wi-Fi, pakai data seluler. Buka dialog unduh Al-Baqarah, lalu Al-Fatihah | Al-Baqarah: ada peringatan kuota dan tombol **Unduh dengan data seluler**. Al-Fatihah (di bawah 50 MB): tanpa peringatan | |
| NF-8-9 (opsional) | Penuhi memori HP sampai sisa ruang lebih kecil dari ukuran Al-Baqarah, buka dialog unduh | Muncul pesan ruang tidak cukup; tombol **Unduh** tidak ada | |
| NF-8-10 | Al-Ikhlas sudah diunduh, Al-Falaq belum. Lanjut otomatis aktif, putar Al-Ikhlas surah penuh | Setelah ayat 4 berhenti, muncul **Surah berikutnya belum diunduh. Murottal berhenti.** | |
| NF-8-11 (kondisi F) | Al-Ikhlas dan Al-Falaq sudah diunduh, mode pesawat, ulangi NF-8-10 | Lanjut ke Al-Falaq; halaman ikut pindah | |
| NF-8-12 | Buka Dengar lalu Tirukan pada surah yang belum diunduh | Muncul ajakan unduh dan tombol **Unduh**; alur tidak mulai. Setelah unduhan selesai, alur mulai sendiri | |
| NF-8-13 (kondisi F) | Surah sudah diunduh dan model suara sudah ada. Mode pesawat, jalankan Dengar lalu Tirukan sampai selesai | Dengar, tirukan, dan penilaian berjalan tanpa internet | |
| NF-8-14 | Ganti qari, buka Al-Fatihah | Surah tampil belum diunduh untuk qari baru. Kembali ke qari lama: Al-Fatihah masih sudah diunduh, tanpa unduh ulang | |
| NF-8-15 | Buka Pengaturan Murottal, lihat daftar unduhan, hapus satu surah | Tiap baris berisi qari, jumlah ayat, dan ukuran. Surah yang dihapus kembali belum diunduh; unduhan qari lain tetap ada | |
| NF-8-16 | Bandingkan perkiraan ukuran di dialog dengan ukuran di Pengaturan setelah unduh | Catat selisihnya. Perkiraan boleh meleset, tapi tidak lebih dari separuh | |
| NF-8-17 (update) | Pasang versi lama sebelum `1c51298`, unduh satu surah, lalu pasang build baru di atasnya | Surah itu tampil **Unduh Ulang Murottal** dan **perlu unduh ulang** di Pengaturan. Setelah unduh ulang selesai, entri lama hilang dari daftar | |
| NF-8-18 ⭐ (kondisi E) | TalkBack aktif, buka dialog unduh, lalu unduh | Pesan, perkiraan ukuran, peringatan kuota, tombol, dan progres dibacakan | |
| NF-8-19 👵🧒 | Minta lansia atau anak mengunduh satu surah lalu memutarnya | Bisa selesai tanpa dibantu. Catat di langkah mana mereka ragu | |

---

## Catatan hasil uji

| ID skenario | Kondisi | Apa yang terjadi | Penguji | Tanggal |
|---|---|---|---|---|
| BC-01-3, BC-03-4 | D, emulator | Lulus. "Tutup lalu buka aplikasi" diganti hot restart; pengaturan dibaca ulang dari penyimpanan, belum dicek dengan tutup dari daftar aplikasi terbaru | Claude (Marionette) | 2026-11-07 |
| BC-01-4, BC-01-5 | D, emulator | Lewati: butuh pasang ulang dan mode pesawat | Claude (Marionette) | 2026-11-07 |
| BC-03-1 | D, emulator | Lewati: bukan pasang baru. Preset **Sedang** memang terpilih di Pengaturan | Claude (Marionette) | 2026-11-07 |
| BC-03-3 | D, emulator | Gagal sampai ke ayat 282. Dengan **Sangat Besar**, tab Juz → Juz 3 (Al-Baqarah 253) berhenti di ayat 38. Penyebab: `_scrollToAyat` di `surah_detail_page.dart` berhenti setelah 60 langkah satu layar; huruf besar butuh lebih banyak. Bookmark dan Last Read memakai fungsi yang sama. Tampilan ayat 282 sendiri belum teruji | Claude (Marionette) | 2026-11-07 |
| BC-03-5 | D, emulator | Lewati: butuh build versi lama | Claude (Marionette) | 2026-11-07 |
| BC-03-2 | D, emulator | Lulus. Catatan kecil: terjemahan Bismillah di preview ("Dengan nama Allah Yang Maha Pengasih, Maha Penyayang") beda dengan di surah ("Dengan menyebut nama Allah Yang Maha Pemurah lagi Maha Penyayang") | Claude (Marionette) | 2026-11-07 |
| BC-04-1 | D, emulator | Lulus. Tiap ikon 48×48 dp, berjejer tanpa celah. Ketukan di tengah ikon memicu aksi yang benar: Tafsir membuka sheet, Simpan mengisi ikon, Putar memutar audio, Bagikan membuka share sheet sistem. Kemudahan untuk lansia dan anak belum dicoba orang sungguhan. Catatan kecil: snackbar "Ayat disimpan" (dengan tombol Batal) tidak hilang sendiri, dan tetap tampil setelah simpan dibatalkan lewat ikon. Sudah diperbaiki 2026-11-08 (`persist: false` dan snackbar ditutup saat batal simpan), dicek ulang 2026-11-08 di emulator: lulus (lihat BC-05-1) | Claude (Marionette) | 2026-11-07 |
| BC-04-2, BC-04-3 | D, emulator, TalkBack mati | Lulus untuk label semantik. Ayat 5 berlabel "Bagikan ayat 5", "Putar ayat 5", "Simpan ayat 5", "Tafsir ayat 5". Saat diputar, label menjadi "Hentikan ayat N" dan ikut pindah ke ayat berikutnya; setelah dihentikan, kembali ke "Putar ayat N". Suara TalkBack sungguhan (kondisi E) belum dicek | Claude (Marionette) | 2026-11-07 |
| BC-05-1, BC-05-2, BC-05-3, BC-06-2 | D, emulator | Lulus. Al-Baqarah:255 diganti ayat 96 karena lompat ke ayat 255 gagal (lihat BC-06-4). Snackbar "Ayat disimpan" hilang sendiri dalam ±13 detik setelah hot reload. Sebelum hot reload snackbar bertahan lebih dari 30 detik karena app masih menjalankan kode sebelum perbaikan `persist: false` | Claude (Marionette) | 2026-11-08 |
| BC-05-4 | D, emulator | Lulus. Yasin:1 dan Al-Baqarah:96 tetap ada setelah hot restart. Percobaan pertama kehilangan Yasin:1, tapi ketukan simpan belum diverifikasi dan restart dilakukan sesaat setelah ketuk. Percobaan kedua menunggu 2 detik dan lulus. Belum dicek: tutup paksa dari daftar aplikasi terbaru, dan restart kurang dari 1 detik setelah simpan | Claude (Marionette) | 2026-11-08 |
| BC-05-5 | D, emulator | Lewati: Marionette tidak bisa mengetuk dalam 1 detik setelah buka aplikasi. Unit test "simpan sebelum load selesai tidak menimpa daftar tersimpan" lulus | Claude (Marionette) | 2026-11-08 |
| BC-06-4 | D, emulator | Gagal. Ketuk "Al-Baqarah · Ayat 96" dengan preset **Sedang** berhenti di ayat 72. Dengan **Kecil**, Juz 3 (tujuan ayat 253) berhenti di ayat 94. Jadi bug BC-03-3 juga terjadi di ukuran bawaan, bukan hanya Sangat Besar. Widget test "initialAyat men-scroll ke ayat tujuan" lulus, tapi tidak mencakup ayat jauh di surah panjang | Claude (Marionette) | 2026-11-08 |
| BC-06-5 | D, emulator | Lulus. Hapus Yasin:1 dari tab Bookmark, ikon di halaman Yasin kembali "Simpan ayat 1". Catatan: ikon hapus langsung menghapus tanpa konfirmasi atau Batal | Claude (Marionette) | 2026-11-08 |
| BC-06-6, BC-06-7 | D, emulator | Lewati: butuh berkas cadangan dan hapus data aplikasi. Unit test "round-trip: bookmark ikut diekspor dan dipulihkan" dan "cadangan lama tanpa kunci bookmark tetap bisa dipulihkan" lulus | Claude (Marionette) | 2026-11-08 |
| BC-07-1, BC-07-2, BC-07-3 | D, emulator | Lulus. WhatsApp tidak terpasang di emulator, jadi lembar bagikan Android diteruskan ke **Copy text**, lalu teksnya ditempel ke kolom cari. Isi pesan (1) Arab, latin, terjemahan, "QS. Al-Ikhlas: 1"; (2) latin mati: tanpa latin, sisanya ada; (3) terjemahan mati: terjemahan tetap ikut. Kolom cari satu baris, jadi pemisah baris tidak terlihat; urutannya tertutup unit test `verse_share_test.dart`. Catatan: kotak Preview di Pengaturan tetap menampilkan latin walau **Tampilkan latin** mati | Claude (Marionette) | 2026-11-08 |
| BC-08-1, BC-09-1 | D, emulator | Lulus. Lima label menu bawah terlihat di tab Quran dan Bookmark, termasuk tab tidak aktif. Kartu **Surat Yasin** membuka Yasin di ayat 1 | Claude (Marionette) | 2026-11-08 |
| BC-08-2 | C, emulator (`font_scale` 2.0 lewat adb, Android 16) | Gagal. Label **Murojaah** dan **Bookmark** terpotong jadi "Muro…" dan "Book…" (maxLines 1, lebar tab 82). Label tidak keluar dari menu. Font sistem dikembalikan ke 1.0 setelah uji | Claude (Marionette) | 2026-11-08 |
| NF-1 | B + C, emulator (`wm density 480` = lebar 360dp, `font_scale` 2.0, Android 16) | Gagal. Dibuka Al-Fatihah, Yasin, Al-Ikhlas: halaman detail rapi, teks turun baris, tanpa garis kuning-hitam. Di daftar surah, nomor 3 digit di dalam bingkai bintang terpotong (108 dan 109 tampil "10") atau meluber (110 sampai 114); info baris disingkat ("Mekk…", "286 A…"); label menu bawah terpotong ("Qur…", "Mur…", "Shal…", "Boo…"). Diulang di C saja (density normal): nomor dan label tetap terpotong, jadi penyebabnya ukuran huruf, bukan layar sempit. Density dan font dikembalikan setelah uji | Claude (Marionette) | 2026-11-08 |
| NF-2 | D, emulator (mode gelap, density dan font normal) | Daftar surah, An-Nas, Al-Ikhlas, Al-Baqarah terbaca jelas. Nomor 3 digit utuh, label menu bawah lengkap, tidak ada teks gelap di latar gelap | Claude (Marionette) | 2026-11-08 |
| NF-3 | E, emulator (label dibaca lewat `uiautomator dump`, TalkBack tidak dinyalakan) | Label ada dan jelas. Halaman utama: "Menu", "Cari surah", "Tab Surah", "Tab Juz", baris surah (nomor, tempat, jumlah ayat, nama), menu bawah. Halaman detail: "Kembali", "Mode terang", "Bagikan/Putar/Simpan/Tafsir ayat N", "Tandai sudah dibaca". Tombol mode gelap/terang hanya ada di halaman detail. Suara TalkBack belum didengar langsung | Claude (Marionette) | 2026-11-08 |
| BL-01-1, BL-01-2 | Emulator, Al-Ikhlas lalu Al-Baqarah (diuji di Al-Baqarah karena Al-Ikhlas selesai sebelum siklus tuntas) | Mini player muncul dengan **1×**. Urutan label terverifikasi 1× → 1.25× → 0.5× → 0.75× → 1×. Kecepatan bertahan saat player ditutup dan dibuka di surah lain. Perubahan suara tidak didengar. Catatan kecil: saat memuat, judul mini player tampil "Surah 112" lalu berganti nama surah | Claude (Marionette) | 2026-11-08 |
| BL-01-3 | Emulator, debug lewat `flutter run` | Setelah pilih 0.75×, `flutter.murottal_speed` di SharedPreferences berisi 0.75. Hot restart gagal (error flutter_tools) dan force-stop akan memutus sesi `flutter run`, jadi tutup lalu buka aplikasi belum diuji. Ulangi manual di build rilis. Kecepatan dikembalikan ke 1× setelah uji | Claude (Marionette) | 2026-11-08 |
| BL-02-1 | Emulator, Al-Ikhlas ayat 1 (durasi 2 detik) | Posisi kembali ke 00:00 dua kali lalu player berhenti dan tertutup; tidak lanjut ke ayat 2. Ikon tombol ulang berubah jadi ulang-satu. Temuan: mode ulang kembali ke **Mati** setelah keluar dari halaman detail surah lalu masuk lagi (aplikasi tidak ditutup) | Claude (Marionette) | 2026-11-08 |
| BL-02-2, BL-03-1 | Emulator, Al-Ikhlas | Terus-menerus: ayat 3 diulang 6 kali dalam 18 detik dan masih berjalan. Rentang 2-4 dengan 3×, mulai dari tombol putar ayat 3: urutan 3, 4, 2, 3, 4, 2, 3, 4 lalu berhenti. Mini player sempat hilang sekejap saat pindah ayat | Claude (Marionette) | 2026-11-08 |
| BL-03-2 | Emulator, Al-Ikhlas (4 ayat) | Dropdown ayat akhir hanya berisi 1 sampai 4. Temuan: ayat akhir yang lebih kecil dari ayat awal tetap bisa dipilih (misalnya awal 3, akhir 1) | Claude (Marionette) | 2026-11-08 |
| BL-04-1, BL-04-3 | Emulator, Al-Ikhlas ayat 4 (durasi 4 detik) | Diputar 3 kali dengan 2 jeda sekitar 5 detik, lalu berhenti. Selama jeda ikon tetap pause dan progress diam di ujung, jadi tidak terlihat bahwa sedang jeda. Pause saat jeda: tetap berhenti selama 8 detik; setelah play, ulangan berikutnya mulai dari 00:00 | Claude (Marionette) | 2026-11-08 |
| BL-04-4 | Emulator, Al-Ikhlas ayat 4, Satu ayat 3× jeda 5 detik | Pause saat jeda, ubah jeda ke 0 detik, tutup sheet, tekan play: ikon berubah ke pause tapi posisi diam di 00:04/00:04 selama 7 detik. Player macet sampai ditutup | Claude (Marionette) | 2026-11-08 |
| BL-04-5 | Emulator, debug lewat `flutter run` | Sama dengan BL-01-3: tutup lalu buka aplikasi belum diuji. Di kode, pengaturan ulang hanya disimpan di memori (tidak ada ke SharedPreferences). Ulangi manual di build rilis | Claude (Marionette) | 2026-11-08 |
| BL-05-1 | Emulator, tab Juz | Item pertama **Juz Amma — surah pendek**, lalu Juz 1, 2, 3 dan seterusnya; item terakhir Juz 29. Label Juz 1 sampai 9 dan 19 sampai 29 dibaca satu per satu; Juz 10 sampai 18 tidak dicek satu per satu (Juz 15 ada). Catatan kecil: posisi gulir tab Juz ikut posisi gulir tab Surah | Claude (Marionette) | 2026-11-08 |
| BL-05-2 | Emulator, Juz 2 | Al-Baqarah terbuka tapi berhenti di ayat 71/72, masih sama setelah ditunggu 6 detik. Dugaan penyebab: `_scrollToAyat` di `surah_detail_page.dart` maju satu layar per percobaan dan berhenti setelah 60 percobaan; ayat Al-Baqarah panjang, jadi 60 layar habis sebelum ayat 142. Juz lain yang mulai jauh di surah panjang kemungkinan kena juga | Claude (Marionette) | 2026-11-08 |
| BL-05-3 | Emulator | Juz 15 terbuka di Al-Isra' ayat 1, Juz 23 di Yasin ayat 28, Juz 30 di An-Naba' ayat 1 | Claude (Marionette) | 2026-11-08 |
| BL-05-4 | Emulator, tanpa TalkBack | Label semantik item Juz Amma: "Juz 30, Juz Amma, surah pendek. Mulai An-Naba' ayat 1". Item lain berlabel "Juz N. Mulai <surah> ayat N". Suara TalkBack belum didengar | Claude (Marionette) | 2026-11-08 |
| BL-08-1 | Emulator, debug lewat VS Code, izin mikrofon belum diberikan, model belum ada | Penyebab ketemu: `ModelDownloader.defaultModelUrl` di `recite_quran` 1.0.5 menunjuk `github.com/Iam-Muslim/Natlu/releases/...`. Repo itu sudah pindah ke `Recite-Quran/Natlu`; URL lama mengembalikan HTTP 504 (dicek dari Mac juga), URL baru 200 (72,7 MB). Folder `recite_quran_assets` dibuat tapi tetap kosong. Setelah sekitar 1 menit spinner (tanpa progres unduhan) muncul **Ada masalah (audio atau mikrofon). Coba lagi.** dan **Mulai lagi**. Pesannya menyesatkan: masalahnya unduhan, bukan audio atau mikrofon. **Mulai lagi** tetap memutar ayat 1 (**Dengarkan…**), lalu error lagi di fase mic. Izin mikrofon tidak pernah diminta (`RECORD_AUDIO granted=false`). Run sebelumnya (macet lebih dari 3 menit) kemungkinan penyebab yang sama. Usulan perbaikan: berikan `modelUrl` baru ke `ModelDownloader(...)` di `ReciteMurojaahService` | Claude (Marionette) | 2026-11-08 |
| BL-08-7 | Baca kode, tidak dijalankan | Halaman ini membuat `MurottalController` baru dan mengambil jeda dari `repeat.value.gapSeconds`. Pengaturan ulang tidak disimpan (lihat BL-04-5), jadi jeda yang diatur di murottal kemungkinan tidak terbawa dan selalu 0. Kecepatan disimpan, jadi 0.75× seharusnya terbawa | Claude (Marionette) | 2026-11-08 |
| NF-5-1 | F, emulator, mode pesawat (`cmd connectivity airplane-mode enable`), sudah pernah online | Lulus. Offline: buka Al-Fatihah, simpan ayat 1, Last Read ikut berubah, ukuran teks diganti ke **Besar**, tab Bookmark, tab Juz, dan Juz 4 (Ali 'Imran) semuanya jalan. Juz 4 seharusnya ke ayat 93 tapi berhenti di ayat 47 (**Besar**) dan 67 (**Sedang**). Itu bug yang sama dengan BC-03-3/BC-06-4, bukan masalah offline. Catatan kecil: sapaan di tab Quran tertulis "Asslamualaikum". Ukuran teks dikembalikan ke **Sedang** setelah uji | Claude (Marionette) | 2026-11-08 |
| NF-5-2 | F, emulator, Al-Ikhlas sudah diunduh (`app_flutter/murottal/05/112.mp3`, 356 KB), mode pesawat | Gagal. Tombol putar ayat 3: mini player langsung menampilkan **Gagal memuat audio: (0) Source error**, sama seperti ayat yang belum diunduh. Penyebab: pemutar hanya memanggil `_player.setUrl(url)` (`murottal_controller.dart`, `_playAyatInternal`) dan tidak pernah membaca file unduhan (lihat BL-07-5). Kecepatan dan ulang tidak bisa diuji karena audio tidak pernah jalan. Mode pesawat dimatikan setelah uji | Claude (Marionette) | 2026-11-08 |
| NF-5-3 | F, emulator, mode pesawat | Lulus. Putar ayat yang belum diunduh: pesan **Tidak dapat terhubung ke server. Periksa koneksi internet Anda.** muncul dalam sekitar 10 detik, dan aplikasi tetap bisa dipakai. Catatan kecil: judul mini player tampil "Surah 1", dan tombol tutup player tidak punya tooltip/label | Claude (Marionette) | 2026-11-08 |
| NF-06 | Emulator | Lewati: harus build commit `9531cc6` lalu pasang dari nol. Itu menghapus data aplikasi di emulator dan memutus sesi debug, jadi butuh persetujuan dulu | Claude (Marionette) | 2026-11-08 |
| NF-7-1 | F, emulator, An-Naba', ulang **Satu ayat** 3×, mode pesawat dinyalakan saat ayat 1 diputar | Saat lanjut ke ayat berikutnya, mini player menampilkan **Gagal memuat audio: (0) Source error**, dan nama surah hilang. Tombol putar memberi pesan yang sama. Teks setelah titik dua berasal dari `$e` di `murottal_controller.dart` baris 302 dan 410. Catatan kecil: tombol putar, sebelumnya, berikutnya, dan tutup di mini player tidak punya label/tooltip | Claude (Marionette) | 2026-11-08 |
| NF-7-2 | Baca kode dan layar yang dibuka selama uji | Gagal. Di layar yang dibuka tidak terlihat "error", "sync", atau "null", kecuali NF-7-1 dan BL-08-1. Di kode, pesan ini bisa menampilkan teks teknis: `'Terjadi kesalahan: $e'` (`doa_controller.dart:167`, `tafsir_controller.dart:84`), `'Download gagal: $e'` (`download_controller.dart:189`), `'Gagal menyiapkan mesin murojaah: $e'` dan `'Gagal membuka mikrofon: $e'` (`recite_murojaah_service.dart:156`, `:179`), `'Terjadi kesalahan jaringan: ${e.message}'` (`dio_error_message.dart:18`). `'Server mengembalikan error $status.'` (`dio_error_message.dart:16`) memakai kata "error" dan kode HTTP. Catatan kecil: label "Download Murottal" berbahasa Inggris | Claude (Marionette) | 2026-11-08 |
| BL-07-1 | Data aplikasi lama, kunci `murottal_auto_next` belum ada di penyimpanan (sama dengan pasang baru) | Toggle tampil aktif. Setelah dimatikan, tersimpan `murottal_auto_next=false`; dinyalakan lagi menjadi `true` | Claude (Marionette) | 2026-11-08 |
| BL-07-2 | Al-Ikhlas sudah diunduh, toggle aktif, tombol **Putar Murottal** | Setelah ayat 4, mini player berganti ke **Al-Falaq · Full Surah** dan audio jalan. Surah penuh diputar per ayat, jadi di antara ayat judul mini player sempat menjadi "Surah 112 · Memuat..." | Claude (Marionette) | 2026-11-08 |
| BL-07-3 | Toggle mati, Al-Ikhlas surah penuh | Berhenti setelah ayat 4; mini player hilang, tidak ada pesan | Claude (Marionette) | 2026-11-08 |
| BL-07-4 | Toggle aktif, tombol putar ayat 4 Al-Ikhlas | Mini player "Ayat 4 / 4", lalu berhenti dan hilang; tidak lanjut ke Al-Falaq | Claude (Marionette) | 2026-11-08 |
| BL-07-5 | An-Nas diunduh (790,5 KB), toggle aktif, surah penuh | Ayat 1 sampai 6 diputar dengan highlight dan auto-scroll, lalu berhenti tanpa error. Temuan: pemutar hanya memanggil `_player.setUrl(url)` per ayat (`murottal_controller.dart`, `_playAyatInternal`). File unduhan `app_flutter/murottal/05/114.mp3` tidak pernah diputar, jadi janji "Setelah download: Offline ready" di dialog unduhan tidak terpenuhi. Terbukti di NF-5-2 | Claude (Marionette) | 2026-11-08 |
| BL-07-6 | Al-Ikhlas, ulang **Rentang ayat** 2 sampai 4, 1×, toggle aktif | Label tombol "Ulang ayat, aktif". Berhenti setelah ayat 4, tidak lanjut ke Al-Falaq. Catatan kecil: pengaturan ulang hilang setiap keluar halaman surah, karena `MurottalController` dibuat per halaman | Claude (Marionette) | 2026-11-08 |
| BL-07-7 | Saat Al-Ikhlas lanjut ke Al-Falaq | Halaman tetap Al-Ikhlas, tanpa highlight ayat yang sedang diputar. Satu-satunya petunjuk adalah judul mini player. Membingungkan: pengguna tidak bisa membaca ayat Al-Falaq yang sedang terdengar | Claude (Marionette) | 2026-11-08 |
| BC-03-3, BC-06-4, BL-05-2, NF-5-1 | Perbaikan, belum diuji ulang | `_scrollToAyat` kini lompat ke perkiraan posisi (tinggi rata-rata ayat terbangun × selisih ayat) lalu diperbaiki tiap frame. Widget test Al-Baqarah 255 dan 282 di **Sangat Besar** lulus. Uji ulang alur Juz dan Bookmark di HP | Claude | 2026-11-08 |
| BL-04-4, BL-03-2 | Perbaikan, belum diuji ulang | Play setelah pause saat jeda dan ubah pengaturan ulang kini lanjut ke ulangan berikutnya. Ayat akhir rentang tidak bisa lebih kecil dari ayat awal. Unit test lulus; audio sungguhan belum didengar | Claude | 2026-11-08 |
| NF-5-3, NF-7-1 | Perbaikan, belum diuji ulang | Tombol mini player punya label (Putar/Jeda, Ayat sebelumnya, Ayat berikutnya, Tutup pemutar). Judul saat memuat memakai nama surah. Pesan gagal audio kini **Gagal memuat audio. Periksa koneksi internet, lalu coba lagi.** | Claude | 2026-11-08 |
| BL-08-1 | Perbaikan, belum diuji ulang | URL unduh model diganti ke asset API GitHub (`Recite-Quran/Natlu`, asset 521426715) dengan header `Accept: application/octet-stream`; URL browser lama dan baru sama-sama 504. Unduhan penuh 72,7 MB berhasil dari Mac. Halaman kini menampilkan persen unduhan, dan bila gagal menampilkan **Unduhan gagal. Periksa internet, lalu coba lagi.** Belum ada tombol coba lagi. Uji ulang BL-08 di HP | Claude | 2026-11-08 |
| NF-7-2 | Perbaikan, belum diuji ulang | Enam pesan teknis diganti kalimat biasa; detail hanya ke log | Claude | 2026-11-08 |
| BC-08-2, NF-1 | Perbaikan, belum diuji ulang | Label menu bawah dan nomor surah mengecil agar utuh saat huruf besar; info baris surah boleh 2 baris. Widget test 360dp skala 2.0 lulus dengan font cadangan, belum dengan Poppins di HP | Claude | 2026-11-08 |
| Catatan kecil | Perbaikan | Sapaan jadi "Assalamualaikum"; "Download" jadi "Unduh"; preview Pengaturan ikut pilihan latin/terjemahan dan memakai terjemahan Bismillah yang sama dengan halaman surah | Claude | 2026-11-08 |
| BL-07-7 | Perbaikan, belum diuji ulang | Saat lanjut otomatis, halaman ikut pindah ke surah baru dan menggulir ke ayat yang diputar. Ekspektasi BL-07-7 diubah | Claude | 2026-11-08 |
| BC-06-5 | Perbaikan, belum diuji ulang | Hapus dari tab Bookmark kini memunculkan snackbar **Ayat dihapus** dengan tombol **Batal**; Batal mengembalikan bookmark dengan waktu simpan aslinya | Claude | 2026-11-08 |
| BL-08-1 | Perbaikan, belum diuji ulang | Bila persiapan Dengar lalu Tirukan gagal, muncul tombol **Coba lagi** | Claude | 2026-11-08 |
| BL-04-5, BL-08-7 | Perbaikan, belum diuji ulang | Mode, jumlah, dan jeda ulang disimpan permanen, jadi jeda dari murottal terbawa ke Dengar lalu Tirukan. Rentang ayat tidak disimpan; mode Rentang dimuat sebagai Mati. Ekspektasi BL-04-5 diubah | Claude | 2026-11-08 |
| BL-04-1 | Perbaikan, belum diuji ulang | Saat jeda antar ulangan, mini player menampilkan **Jeda… N** dengan lingkaran kecil, dan tombol putar jadi **Lewati jeda**. Label TalkBack "Jeda N detik sebelum ulangan berikutnya" belum dicek di HP. Selama jeda tombol Jeda tidak tampil; jeda bisa dihentikan dengan menutup pemutar | Claude | 2026-11-08 |
| NF-5-2, BL-07-5 | Perbaikan, belum diuji ulang | Murottal kini hanya diputar dari file per ayat di HP (`murottal/{qari}/{SSS}/{AAA}.mp3`); tidak ada lagi pemutaran online atau panggilan API saat memutar. Surah yang belum diunduh menampilkan ajakan unduh. Skenario baru: NF-08. Build Android dan iOS lulus kompilasi, belum dicoba di HP | Claude | 2026-11-08 |
