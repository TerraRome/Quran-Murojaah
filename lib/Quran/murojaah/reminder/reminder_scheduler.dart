/// Status izin notifikasi yang bisa ditampilkan ke pengguna.
enum ReminderPermission {
  /// Belum pernah ditanya / belum diperiksa.
  unknown,

  granted,

  /// Ditolak. Bukan error — UI menampilkan penjelasan dan jalan ke pengaturan.
  denied,
}

/// Antarmuka tipis di atas plugin notifikasi.
///
/// Semua logika penjadwalan ada di [ReminderPlanner] dan `MurojaahReminder`;
/// kelas ini hanya jembatan ke sistem. Implementasi palsu dipakai di test,
/// sehingga tidak ada test yang menyentuh plugin atau perangkat.
abstract class ReminderScheduler {
  /// Minta izin ke sistem (Android 13+ / iOS). Hasilnya izin saat ini.
  Future<bool> requestPermission();

  /// Cek izin tanpa memunculkan dialog.
  Future<bool> hasPermission();

  /// Pasang satu notifikasi sekali-tampil pada [at].
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  });

  /// Batalkan pengingat milik fitur ini saja — jangan sentuh notifikasi lain.
  Future<void> cancel();

  /// Buka pengaturan sistem aplikasi (jalan keluar saat izin ditolak).
  Future<void> openSystemSettings();
}
