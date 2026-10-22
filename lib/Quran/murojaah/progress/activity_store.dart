import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'activity_entry.dart';

/// Versi format JSON yang ditulis sekarang.
///
/// Naikkan saat bentuk berkas berubah. Parser tetap menerima berkas versi lama
/// (termasuk bentuk sebelum ada versi, yaitu array polos).
const int activitySchemaVersion = 3;

/// Penyimpanan log aktivitas murojaah.
///
/// Abstrak supaya mesin hitung progres tidak bergantung pada media simpan, dan
/// supaya test memakai memori. Implementasi bawaan memakai [SharedPreferences]
/// mengikuti pola `LastReadStore`: log bersifat append-only dan kecil (beberapa
/// baris per hari), jadi JSON satu kunci sudah cukup.
///
/// ponytail: batas atas ± ribuan entri. Pindah ke Drift/SQLite kalau log perlu
/// difilter per rentang tanggal atau tumbuh > ~10 ribu entri.
abstract class ActivityStore {
  Future<List<ActivityEntry>> load();

  Future<void> append(ActivityEntry entry);
}

class PrefsActivityStore implements ActivityStore {
  const PrefsActivityStore();

  static const key = 'quran_activity_log_v1';

  @override
  Future<List<ActivityEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    return decodeActivityLog(raw);
  }

  @override
  Future<void> append(ActivityEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await load();
    final next = [...all, entry]..sort((a, b) => a.at.compareTo(b.at));
    await prefs.setString(key, encodeActivityLog(next));
  }
}

/// Baca log dari JSON. Menerima dua bentuk:
/// - `{"version": n, "entries": [...]}` (versi sekarang),
/// - `[...]` array polos (format lama, sebelum ada `version`).
///
/// Entri rusak dilewati satu per satu — satu baris cacat tidak membuang seluruh
/// riwayat.
List<ActivityEntry> decodeActivityLog(String raw) {
  final decoded = jsonDecode(raw);
  final list = switch (decoded) {
    List() => decoded,
    {'entries': final List entries} => entries,
    _ => const [],
  };
  return [for (final item in list) ?ActivityEntry.fromJson(item)];
}

String encodeActivityLog(List<ActivityEntry> entries) => jsonEncode({
  'version': activitySchemaVersion,
  'entries': [for (final e in entries) e.toJson()],
});

/// Store di memori — untuk test dan pratinjau.
class MemoryActivityStore implements ActivityStore {
  MemoryActivityStore([List<ActivityEntry> seed = const []])
    : _entries = [...seed];

  final List<ActivityEntry> _entries;

  @override
  Future<List<ActivityEntry>> load() async => List.unmodifiable(_entries);

  @override
  Future<void> append(ActivityEntry entry) async => _entries.add(entry);
}
