import 'waktu_shalat.dart';

/// Jadwal shalat satu bulan untuk satu lokasi.
class JadwalShalat {
  const JadwalShalat({
    required this.provinsi,
    required this.kabkota,
    required this.bulan,
    required this.tahun,
    required this.bulanNama,
    required this.jadwal,
  });

  final String provinsi;
  final String kabkota;
  final int bulan;
  final int tahun;
  final String bulanNama;
  final List<WaktuShalat> jadwal;

  /// Get waktu shalat untuk tanggal tertentu (1-31). Null jika tidak ada.
  WaktuShalat? getByTanggal(int tanggal) =>
      jadwal.where((w) => w.tanggal == tanggal).firstOrNull;

  /// Get waktu shalat hari ini berdasarkan DateTime.now().
  WaktuShalat? get today {
    final now = DateTime.now();
    if (now.year != tahun || now.month != bulan) return null;
    return getByTanggal(now.day);
  }
}
