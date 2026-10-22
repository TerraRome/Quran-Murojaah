import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_entry.dart';
import 'activity_store.dart';
import 'progress_service.dart';
import 'record_result.dart';

/// Sumber angka progres untuk UI: memuat log, mencatat aktivitas baru, dan
/// menghitung ulang snapshot setiap kali log berubah.
///
/// Semua angka tetap diturunkan dari log (tidak ada agregat tersimpan), jadi
/// menghapus satu entri otomatis memperbaiki streak/XP.
class MurojaahProgressController extends ChangeNotifier {
  MurojaahProgressController({ActivityStore store = const PrefsActivityStore()})
    : _store = store;

  static const _keyGoal = 'quran_murojaah_goal_verses';

  final ActivityStore _store;

  List<ActivityEntry> _entries = const [];
  DailyGoal _goal = DailyGoal.sedang;
  bool _loaded = false;
  bool _disposed = false;

  DailyGoal get goal => _goal;
  bool get isLoaded => _loaded;
  List<ActivityEntry> get entries => List.unmodifiable(_entries);

  ProgressSnapshot snapshot({DateTime? now}) => ProgressService(
    _entries,
    verseCount: verseCount,
  ).snapshot(now: now ?? DateTime.now(), goal: _goal);

  /// Jumlah ayat per surah, disuntikkan dari daftar surah yang sudah dimuat.
  ///
  /// Null = belum diketahui; bonus surah tamat tidak diberikan sampai terisi.
  int Function(int surahNumber)? verseCount;

  Future<void> load() async {
    _entries = await _store.load();
    final prefs = await SharedPreferences.getInstance();
    _goal = DailyGoal.fromVerses(prefs.getInt(_keyGoal));
    _loaded = true;
    _notify();
  }

  Future<void> setGoal(DailyGoal goal) async {
    if (goal == _goal) return;
    _goal = goal;
    _notify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGoal, goal.verses);
  }

  /// Catat satu rentang ayat yang selesai dibaca.
  ///
  /// Pemanggil hanya boleh memanggil ini untuk bacaan yang benar-benar selesai
  /// (surah tamat atau sesi dihentikan), bukan per kata. Murottal tidak lewat
  /// sini.
  ///
  /// Mengembalikan apa yang berubah karena entri ini — dihitung dengan
  /// membandingkan snapshot sebelum dan sesudah, memakai satu nilai waktu
  /// ([at]) supaya bacaan tepat tengah malam tidak terbelah dua hari.
  Future<RecordResult> record({
    required int surahNumber,
    required int fromVerse,
    required int toVerse,
    ActivityType type = ActivityType.murojaah,
    double? accuracy,
    String? refId,
    DateTime? at,
  }) async {
    if (toVerse < fromVerse || fromVerse < 1) return RecordResult.none;

    final now = at ?? DateTime.now();
    final before = snapshot(now: now);
    final entry = ActivityEntry(
      at: now,
      surahNumber: surahNumber,
      fromVerse: fromVerse,
      toVerse: toVerse,
      type: type,
      accuracy: accuracy,
      refId: refId,
    );
    await _store.append(entry);
    _entries = [..._entries, entry];
    final after = snapshot(now: now);
    _notify();

    return _diff(before, after);
  }

  /// Catat sekumpulan ayat (boleh tidak berurutan) sebagai rentang berurutan.
  ///
  /// Ayat yang sudah tercatat hari ini untuk jenis ini dilewati — dedupe
  /// harian lintas sesi. Mengembalikan gabungan hasil semua rentang.
  Future<RecordResult> recordVerses({
    required ActivityType type,
    required int surahNumber,
    required Iterable<int> verses,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final seen = {
      for (final e in _entries)
        if (e.type == type && e.surahNumber == surahNumber && e.day == today)
          for (var v = e.fromVerse; v <= e.toVerse; v++) v,
    };
    final fresh = verses.where((v) => v > 0 && !seen.contains(v)).toSet().toList()
      ..sort();
    if (fresh.isEmpty) return RecordResult.none;

    var start = fresh.first;
    var prev = start;
    var result = RecordResult.none;
    for (final verse in fresh.skip(1)) {
      if (verse == prev + 1) {
        prev = verse;
        continue;
      }
      result = result + await record(
        surahNumber: surahNumber,
        fromVerse: start,
        toVerse: prev,
        type: type,
        at: now,
      );
      start = verse;
      prev = verse;
    }
    return result +
        await record(
          surahNumber: surahNumber,
          fromVerse: start,
          toVerse: prev,
          type: type,
          at: now,
        );
  }

  /// Catat satu doa yang dibaca. Satu doa dihitung sekali per hari.
  Future<RecordResult> recordDoa({required String refId, DateTime? at}) async {
    final now = at ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final already = _entries.any(
      (e) => e.type == ActivityType.doa && e.refId == refId && e.day == today,
    );
    if (already) return RecordResult.none;
    return record(
      surahNumber: ActivityEntry.noSurah,
      fromVerse: 1,
      toVerse: 1,
      type: ActivityType.doa,
      refId: refId,
      at: now,
    );
  }

  RecordResult _diff(ProgressSnapshot before, ProgressSnapshot after) {
    return RecordResult(
      xpGained: after.todayXp - before.todayXp,
      streakIncreased: !before.activeToday && after.activeToday,
      goalJustReached: !before.goalReached && after.goalReached,
      newStreak: after.streak,
      newLevel: after.level,
      leveledUp: after.level > before.level,
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
