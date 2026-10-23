/// Rencana pengingat harian: kapan saja notifikasi dipasang dan apa bunyinya.
///
/// Murni hitungan — tanpa plugin, tanpa penyimpanan, tanpa widget. Semua waktu
/// dibangun dari [DateTime] lokal, jadi test bisa memakai jam palsu.
class ReminderPlan {
  const ReminderPlan({
    required this.times,
    required this.title,
    required this.body,
    String? followUpBody,
  }) : followUpBody = followUpBody ?? body;

  static const empty = ReminderPlan(times: [], title: '', body: '');

  /// Waktu notifikasi terpasang, urut naik. Kosong = tidak ada pengingat.
  final List<DateTime> times;

  final String title;

  /// Bunyi notifikasi **pertama** — boleh memuat angka streak.
  final String body;

  /// Bunyi notifikasi berikutnya dalam jendela yang sama.
  ///
  /// Sengaja tanpa angka: angka streak yang sama dikirim ulang dua hari
  /// kemudian akan berbohong kalau pengguna tidak membuka aplikasi.
  final String followUpBody;

  /// Bunyi untuk notifikasi ke-[index] (0 = yang pertama).
  String bodyAt(int index) => index == 0 ? body : followUpBody;

  bool get isEmpty => times.isEmpty;
}

/// Aturan satu pengingat murojaah per hari.
///
/// Tiga keputusan yang dijaga di sini:
/// - hanya satu notifikasi per hari, pada jam pilihan;
/// - hari yang sudah aktif tidak diingatkan lagi — jadwal bergeser ke besok;
/// - pengingat dipasang paling banyak [maxDays] hari ke depan, jadi kalau
///   aplikasi tidak dibuka beberapa hari, pengingat berhenti sendiri (tidak
///   jadi spam). Setiap kali aplikasi dibuka atau progres dicatat, jendela itu
///   dipasang ulang.
class ReminderPlanner {
  const ReminderPlanner._();

  /// Jam default pengingat (20:00) — setelah maghrib, sebelum tidur.
  static const defaultHour = 20;
  static const defaultMinute = 0;

  /// Batas hari tanpa membuka aplikasi sebelum pengingat berhenti.
  static const maxDays = 3;

  static ReminderPlan plan({
    required DateTime now,
    required int hour,
    required int minute,
    required bool activeToday,
    required int streak,
  }) {
    final times = <DateTime>[];
    var day = DateTime(now.year, now.month, now.day);
    if (activeToday) day = DateTime(day.year, day.month, day.day + 1);

    // Paling banyak maxDays+1 putaran: hari ini mungkin sudah lewat jamnya.
    for (var i = 0; i <= maxDays && times.length < maxDays; i++) {
      final at = DateTime(day.year, day.month, day.day + i, hour, minute);
      if (at.isAfter(now)) times.add(at);
    }

    return ReminderPlan(
      times: List.unmodifiable(times),
      title: 'Waktunya murojaah',
      body: streak > 0
          ? 'Streak $streak hari masih berjalan. Satu ayat sebentar sudah cukup.'
          : 'Belum ada bacaan hari ini. Satu ayat sudah cukup untuk mulai.',
      // Notifikasi hari ke-2 dan ke-3 dikirim tanpa membuka aplikasi, jadi
      // angka streak di layar sudah tidak pasti. Pakai teks netral.
      followUpBody: 'Waktunya murojaah. Satu ayat hari ini sudah cukup.',
    );
  }
}
