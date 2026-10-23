import '../progress/activity_store.dart';
import '../progress/progress_controller.dart';
import '../progress/progress_service.dart';
import '../reminder/reminder_controller.dart';
import 'backup_document.dart';

/// Ekspor & impor cadangan: rakitan dari store log + pengaturan yang sudah ada.
///
/// Tidak menyimpan state sendiri — semua angka tetap berasal dari
/// [MurojaahProgressController] dan [MurojaahReminder], jadi setelah impor UI
/// ikut berubah lewat notifier yang sama.
class MurojaahBackup {
  MurojaahBackup({required this.progress, required this.reminder});

  final MurojaahProgressController progress;
  final MurojaahReminder reminder;

  /// Snapshot teks JSON dari kondisi sekarang.
  BackupDocument document() => BackupDocument(
    entries: progress.entries,
    goalVerses: progress.goal.verses,
    reminderEnabled: reminder.enabled,
    reminderHour: reminder.hour,
    reminderMinute: reminder.minute,
  );

  String exportJson() => document().encode();

  /// Baca berkas tanpa mengubah apa pun. Aman dipanggil sebelum konfirmasi.
  BackupParse parse(String raw) => decodeBackup(raw);

  /// Berapa entri yang akan bertambah bila [document] diimpor sekarang.
  ///
  /// Dipakai untuk ringkasan "N entri baru" **sebelum** menyimpan.
  int countNew(BackupDocument document) =>
      newEntries(progress.entries, document.entries).length;

  /// Terapkan cadangan: gabungkan entri, pulihkan target dan pengaturan
  /// pengingat, lalu bangun ulang jadwal notifikasi.
  ///
  /// Mengembalikan jumlah entri baru. Entri yang id-nya sudah ada tidak
  /// ditimpa dan tidak dihitung.
  Future<int> import(BackupDocument document) async {
    final fresh = newEntries(progress.entries, document.entries);
    if (fresh.isNotEmpty) {
      await progress.replaceEntries([...progress.entries, ...fresh]);
    }
    await progress.restoreGoal(DailyGoal.fromVerses(document.goalVerses));
    await reminder.restoreSettings(
      enabled: document.reminderEnabled,
      hour: document.reminderHour,
      minute: document.reminderMinute,
    );
    // Log berubah → status hari ini dan streak berubah. Jadwal dipasang ulang
    // dengan angka baru supaya teks notifikasi tidak memakai streak lama.
    final snapshot = progress.snapshot();
    await reminder.sync(
      activeToday: snapshot.activeToday,
      streak: snapshot.streak,
    );
    return fresh.length;
  }

  /// Bandingkan kondisi sekarang dengan isi berkas — dasar test round-trip.
  bool matches(BackupDocument other) {
    final mine = document();
    if (mine.goalVerses != other.goalVerses) return false;
    if (mine.reminderEnabled != other.reminderEnabled) return false;
    if (mine.reminderHour != other.reminderHour) return false;
    if (mine.reminderMinute != other.reminderMinute) return false;
    if (mine.entries.length != other.entries.length) return false;
    final ids = {for (final e in mine.entries) e.id};
    return other.entries.every((e) => ids.contains(e.id));
  }
}

/// Ringkasan singkat untuk dialog konfirmasi.
String importSummary(int count) => count == 0
    ? 'Tidak ada entri baru — semua data di berkas sudah ada.'
    : '$count entri baru siap ditambahkan.';

/// Pesan untuk entri yang dilewati karena rusak (bila ada).
String skippedEntriesNote(int skipped) => skipped == 0
    ? ''
    : '$skipped entri dilewati karena tidak terbaca.';
