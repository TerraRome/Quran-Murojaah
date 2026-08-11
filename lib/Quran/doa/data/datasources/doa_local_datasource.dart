import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/doa_model.dart';

/// Local data source untuk cache doa + bookmark via SharedPreferences.
///
/// Keys:
///   doa_cache        → JSON string List<DoaModel>
///   doa_bookmarks    → JSON string List<int> (id)
class DoaLocalDataSource {
  static const _cacheKey = 'doa_cache';
  static const _bookmarkKey = 'doa_bookmarks';

  // ── Cache ────────────────────────────────────────────────────────────────

  /// Simpan semua doa ke cache.
  Future<void> saveDoas(List<DoaModel> doas) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(doas.map((d) => d.toJson()).toList());
    await prefs.setString(_cacheKey, encoded);
  }

  /// Baca cache doa. Null jika belum ada.
  Future<List<DoaModel>?> getCachedDoas() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => DoaModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Cache korup — hapus dan kembalikan null
      await prefs.remove(_cacheKey);
      return null;
    }
  }

  /// Hapus cache.
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  // ── Bookmark ─────────────────────────────────────────────────────────────

  /// Baca semua id yang di-bookmark.
  Future<Set<int>> getBookmarkedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookmarkKey);
    if (raw == null) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => (e as num).toInt()).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Toggle bookmark untuk satu doa. Kembalikan state baru (true = bookmarked).
  Future<bool> toggleBookmark(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await getBookmarkedIds();
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    await prefs.setString(_bookmarkKey, jsonEncode(ids.toList()));
    return ids.contains(id);
  }

  /// Cek apakah satu doa di-bookmark.
  Future<bool> isBookmarked(int id) async {
    final ids = await getBookmarkedIds();
    return ids.contains(id);
  }
}
