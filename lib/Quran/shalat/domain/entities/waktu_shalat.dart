/// Waktu shalat untuk satu hari.
class WaktuShalat {
  const WaktuShalat({
    required this.tanggal,
    required this.tanggalLengkap,
    required this.hari,
    required this.imsak,
    required this.subuh,
    required this.terbit,
    required this.dhuha,
    required this.dzuhur,
    required this.ashar,
    required this.maghrib,
    required this.isya,
  });

  final int tanggal;
  final String tanggalLengkap; // YYYY-MM-DD
  final String hari;
  final String imsak;
  final String subuh;
  final String terbit;
  final String dhuha;
  final String dzuhur;
  final String ashar;
  final String maghrib;
  final String isya;

  /// Parse waktu HH:mm ke DateTime hari ini.
  DateTime parseTime(String time) {
    final parts = time.split(':');
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  /// Get all waktu as list (nama, waktu string, DateTime).
  List<ShalatEntry> get allWaktu => [
        ShalatEntry('Imsak', imsak, parseTime(imsak)),
        ShalatEntry('Subuh', subuh, parseTime(subuh)),
        ShalatEntry('Terbit', terbit, parseTime(terbit)),
        ShalatEntry('Dhuha', dhuha, parseTime(dhuha)),
        ShalatEntry('Dzuhur', dzuhur, parseTime(dzuhur)),
        ShalatEntry('Ashar', ashar, parseTime(ashar)),
        ShalatEntry('Maghrib', maghrib, parseTime(maghrib)),
        ShalatEntry('Isya', isya, parseTime(isya)),
      ];
}

/// Entry waktu shalat (nama, string waktu, DateTime).
class ShalatEntry {
  const ShalatEntry(this.nama, this.waktu, this.dateTime);
  final String nama;
  final String waktu; // HH:mm
  final DateTime dateTime;
}
