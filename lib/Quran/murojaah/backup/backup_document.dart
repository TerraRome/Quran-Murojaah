import 'dart:convert';

import '../progress/activity_entry.dart';
import '../progress/activity_store.dart';

/// Versi format berkas cadangan (amplopnya, bukan isi log).
///
/// Naikkan hanya kalau bentuk amplop berubah. Isi log punya versinya sendiri
/// ([activitySchemaVersion]) supaya berkas lama tetap bisa dibaca.
const int backupVersion = 1;

/// Penanda aplikasi — menolak berkas milik aplikasi lain yang kebetulan JSON.
const String backupAppId = 'quran-murojaah';

/// Isi satu berkas cadangan: log lengkap + pengaturan yang menyertainya.
class BackupDocument {
  const BackupDocument({
    required this.entries,
    required this.goalVerses,
    required this.reminderEnabled,
    required this.reminderHour,
    required this.reminderMinute,
    this.exportedAt,
  });

  final List<ActivityEntry> entries;
  final int goalVerses;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final DateTime? exportedAt;

  Map<String, Object?> toJson() => {
    'app': backupAppId,
    'backupVersion': backupVersion,
    'activitySchemaVersion': activitySchemaVersion,
    'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
    'goalVerses': goalVerses,
    'reminder': {
      'enabled': reminderEnabled,
      'hour': reminderHour,
      'minute': reminderMinute,
    },
    'entries': [for (final e in entries) e.toJson()],
  };

  String encode({bool pretty = true}) =>
      pretty ? const JsonEncoder.withIndent('  ').convert(toJson()) : jsonEncode(toJson());
}

/// Hasil membaca berkas cadangan.
sealed class BackupParse {
  const BackupParse();
}

class BackupOk extends BackupParse {
  const BackupOk(this.document);
  final BackupDocument document;
}

class BackupInvalid extends BackupParse {
  const BackupInvalid(this.message);

  /// Kalimat siap tampil ke pengguna.
  final String message;
}

/// Baca teks JSON menjadi [BackupDocument], atau [BackupInvalid] dengan alasan
/// yang bisa dibaca manusia. Tidak pernah melempar.
BackupParse decodeBackup(String raw) {
  if (raw.trim().isEmpty) {
    return const BackupInvalid('Berkas kosong. Pilih berkas cadangan yang benar.');
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const BackupInvalid(
      'Berkas tidak bisa dibaca: bukan JSON yang valid.',
    );
  }

  if (decoded is! Map) {
    return const BackupInvalid('Berkas bukan cadangan aplikasi ini.');
  }

  if (decoded['app'] != backupAppId) {
    return const BackupInvalid('Berkas bukan cadangan aplikasi ini.');
  }

  final version = decoded['backupVersion'];
  if (version is! int) {
    return const BackupInvalid('Berkas cadangan tidak punya versi format.');
  }
  if (version > backupVersion) {
    return const BackupInvalid(
      'Cadangan dibuat aplikasi versi lebih baru. Perbarui aplikasi dulu, '
      'lalu coba lagi.',
    );
  }

  final schema = decoded['activitySchemaVersion'];
  if (schema is! int) {
    return const BackupInvalid('Berkas cadangan tidak punya versi data.');
  }
  if (schema > activitySchemaVersion) {
    return const BackupInvalid(
      'Data cadangan dibuat aplikasi versi lebih baru. Perbarui aplikasi dulu.',
    );
  }

  final rawEntries = decoded['entries'];
  if (rawEntries is! List) {
    return const BackupInvalid('Berkas cadangan tidak berisi daftar entri.');
  }

  final entries = <ActivityEntry>[];
  for (final item in rawEntries) {
    final entry = ActivityEntry.fromJson(item);
    if (entry != null) entries.add(entry);
  }
  if (entries.isEmpty && rawEntries.isNotEmpty) {
    return const BackupInvalid('Semua entri di berkas rusak atau tidak dikenali.');
  }

  final reminder = decoded['reminder'];
  final goal = decoded['goalVerses'];

  return BackupOk(
    BackupDocument(
      entries: entries,
      goalVerses: goal is int && goal > 0 ? goal : 15,
      reminderEnabled: reminder is Map && reminder['enabled'] == true,
      reminderHour: _clampInt(
        reminder is Map ? reminder['hour'] : null,
        0,
        23,
        20,
      ),
      reminderMinute: _clampInt(
        reminder is Map ? reminder['minute'] : null,
        0,
        59,
        0,
      ),
      exportedAt: DateTime.tryParse('${decoded['exportedAt']}'),
    ),
  );
}

int _clampInt(Object? raw, int min, int max, int fallback) {
  if (raw is! int) return fallback;
  if (raw < min || raw > max) return fallback;
  return raw;
}
