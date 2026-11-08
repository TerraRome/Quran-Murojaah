import 'package:shared_preferences/shared_preferences.dart';

import 'repeat_sequencer.dart';

/// Menyimpan kecepatan putar (BL-01) dan lanjut otomatis ke surah berikutnya
/// (BL-07, default aktif).
class MurottalPrefsStore {
  const MurottalPrefsStore();

  static const keySpeed = 'murottal_speed';
  static const keyAutoNext = 'murottal_auto_next';
  static const keyRepeatMode = 'murottal_repeat_mode';
  static const keyRepeatCount = 'murottal_repeat_count';
  static const keyRepeatGap = 'murottal_repeat_gap';
  static const List<double> speeds = [0.5, 0.75, 1.0, 1.25];

  Future<double> loadSpeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getDouble(keySpeed);
      return v != null && speeds.contains(v) ? v : 1.0;
    } catch (_) {
      return 1.0;
    }
  }

  Future<void> saveSpeed(double v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(keySpeed, v);
    } catch (_) {}
  }

  Future<bool> loadAutoNext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyAutoNext) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> saveAutoNext(bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyAutoNext, v);
    } catch (_) {}
  }

  /// Pengaturan ulang (BL-04): mode, jumlah, dan jeda disimpan permanen.
  /// Rentang ayat spesifik per surah, jadi tidak disimpan; mode rentang
  /// dimuat sebagai mati karena rentang bawaan (ayat 1-1) membingungkan.
  Future<RepeatSettings> loadRepeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = RepeatKind.values.asNameMap()[prefs.getString(keyRepeatMode)];
      final count = prefs.getInt(keyRepeatCount);
      final gap = prefs.getInt(keyRepeatGap);
      return RepeatSettings(
        mode: mode == null || mode == RepeatKind.range ? RepeatKind.off : mode,
        count: count != null && RepeatSettings.counts.contains(count)
            ? count
            : const RepeatSettings().count,
        gapSeconds: gap != null && RepeatSettings.gaps.contains(gap) ? gap : 0,
      );
    } catch (_) {
      return const RepeatSettings();
    }
  }

  Future<void> saveRepeat(RepeatSettings s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyRepeatMode, s.mode.name);
      await prefs.setInt(keyRepeatCount, s.count);
      await prefs.setInt(keyRepeatGap, s.gapSeconds);
    } catch (_) {}
  }
}
