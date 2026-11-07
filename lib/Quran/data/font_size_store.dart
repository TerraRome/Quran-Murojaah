import 'package:shared_preferences/shared_preferences.dart';

/// Paket ukuran teks (Arab / Latin / terjemahan) yang bisa dipilih di Pengaturan.
class TextSizePreset {
  const TextSizePreset(this.label, this.arabic, this.latin, this.translation);

  final String label;
  final double arabic;
  final double latin;
  final double translation;

  static const kecil = TextSizePreset('Kecil', 22, 14, 14);
  static const sedang = TextSizePreset('Sedang', 28, 16, 18);
  static const besar = TextSizePreset('Besar', 36, 20, 22);
  static const sangatBesar = TextSizePreset('Sangat Besar', 44, 24, 26);
  static const all = [kecil, sedang, besar, sangatBesar];

  /// Preset yang ukurannya persis sama; null bila ukuran kustom (data lama).
  static TextSizePreset? match(double arabic, double latin, double translation) {
    for (final p in all) {
      if (p.arabic == arabic && p.latin == latin && p.translation == translation) {
        return p;
      }
    }
    return null;
  }
}

/// Menyimpan ukuran font Arab, Latin & terjemahan secara lokal.
class FontSizeStore {
  const FontSizeStore();

  static const _keyArabic = 'quran_font_size_arabic';
  static const _keyTranslation = 'quran_font_size_translation';
  static const _keyLatin = 'quran_font_size_latin';
  static const defaultArabic = 28.0;
  static const defaultLatin = 16.0;
  static const defaultTranslation = 18.0;

  Future<double> loadLatin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_keyLatin) ?? defaultLatin;
    } catch (_) {
      return defaultLatin;
    }
  }

  Future<void> saveLatin(double size) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyLatin, size);
    } catch (_) {}
  }

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
      await prefs.remove(_keyLatin);
    } catch (_) {}
  }
}
