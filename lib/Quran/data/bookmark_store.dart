import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../application/bookmark.dart';

/// Menyimpan daftar ayat tersimpan secara lokal (BC-05) sebagai satu list JSON.
class BookmarkStore {
  const BookmarkStore();

  static const _key = 'quran_bookmarks';

  Future<List<Bookmark>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded) ?Bookmark.fromJson(item),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<Bookmark> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode([for (final b in items) b.toJson()]),
      );
    } catch (_) {}
  }
}
