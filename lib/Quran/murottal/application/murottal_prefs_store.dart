import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan kecepatan putar (BL-01) dan lanjut otomatis ke surah berikutnya
/// (BL-07, default aktif).
class MurottalPrefsStore {
  const MurottalPrefsStore();

  static const keySpeed = 'murottal_speed';
  static const keyAutoNext = 'murottal_auto_next';
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
}
