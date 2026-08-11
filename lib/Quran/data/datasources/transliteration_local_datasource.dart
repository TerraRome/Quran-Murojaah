import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cache lokal untuk data transliteration (teksLatin) per surah.
///
/// Data disimpan di SharedPreferences sebagai JSON string per surah.
/// Key format: `transliteration_surah_{number}` (misal: `transliteration_surah_36`)
/// Value format: `{"1":"Yā sīn.","2":"Wal-qur'ānil-ḥakīm(i).",...}`
///
/// Flag `transliteration_all_fetched` menandai bahwa semua 114 surah
/// sudah pernah di-fetch dan di-cache — digunakan untuk skip prefetch
/// pada boot berikutnya.
class TransliterationLocalDataSource {
  static const String _keyPrefix = 'transliteration_surah_';
  static const String _keyAllFetched = 'transliteration_all_fetched';

  /// Simpan data transliteration untuk satu surah.
  Future<void> save(int surahNumber, Map<int, String> data) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      data.map((k, v) => MapEntry(k.toString(), v)),
    );
    await prefs.setString('$_keyPrefix$surahNumber', encoded);
  }

  /// Muat data transliteration untuk satu surah dari cache.
  /// Mengembalikan `null` jika belum pernah di-cache.
  Future<Map<int, String>?> load(int surahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$surahNumber');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(int.parse(k), v as String));
    } catch (_) {
      return null;
    }
  }

  /// Apakah data transliteration untuk surah ini sudah ada di cache.
  Future<bool> isCached(int surahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_keyPrefix$surahNumber');
  }

  /// Tandai bahwa semua 114 surah sudah berhasil di-fetch dan di-cache.
  Future<void> markAllFetched() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAllFetched, true);
  }

  /// Apakah semua 114 surah sudah pernah di-fetch sebelumnya.
  Future<bool> get isAllFetched async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAllFetched) ?? false;
  }

  /// Hapus semua cache transliteration (untuk keperluan debug/reset).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(_keyPrefix) || k == _keyAllFetched)
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
