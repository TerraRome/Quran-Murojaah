import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan pilihan tampilkan/sembunyikan latin & terjemahan (default: tampil).
class DisplayStore {
  const DisplayStore();

  static const keyShowLatin = 'quran_show_latin';
  static const keyShowTranslation = 'quran_show_translation';

  Future<bool> loadShowLatin() => _load(keyShowLatin);
  Future<bool> loadShowTranslation() => _load(keyShowTranslation);
  Future<void> saveShowLatin(bool v) => _save(keyShowLatin, v);
  Future<void> saveShowTranslation(bool v) => _save(keyShowTranslation, v);

  Future<bool> _load(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _save(String key, bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, v);
    } catch (_) {}
  }
}
