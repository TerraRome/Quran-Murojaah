import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan ukuran font Arab & terjemahan secara lokal.
class FontSizeStore {
  const FontSizeStore();

  static const _keyArabic = 'quran_font_size_arabic';
  static const _keyTranslation = 'quran_font_size_translation';
  static const defaultArabic = 18.0;
  static const defaultTranslation = 16.0;

  Future<double> loadArabic() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_keyArabic) ?? defaultArabic;
    } catch (_) {
      return defaultArabic;
    }
  }

  Future<double> loadTranslation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_keyTranslation) ?? defaultTranslation;
    } catch (_) {
      return defaultTranslation;
    }
  }

  Future<void> saveArabic(double size) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyArabic, size);
    } catch (_) {}
  }

  Future<void> saveTranslation(double size) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyTranslation, size);
    } catch (_) {}
  }

  Future<void> resetAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyArabic);
      await prefs.remove(_keyTranslation);
    } catch (_) {}
  }
}
