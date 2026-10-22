import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan pilihan mode terang/gelap secara lokal.
///
/// Dipisah dari [QuranThemeController] supaya controller tetap bisa diuji tanpa
/// penyimpanan, dan supaya kegagalan prefs tidak pernah menjatuhkan tema.
class ThemeStore {
  const ThemeStore();

  static const keyDark = 'quran_theme_dark';

  Future<bool> loadDark() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyDark) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveDark(bool dark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyDark, dark);
    } catch (_) {}
  }
}
