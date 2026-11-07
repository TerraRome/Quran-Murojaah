import 'package:flutter/foundation.dart';

import '../data/bookmark_store.dart';
import 'bookmark.dart';

/// Daftar ayat tersimpan yang dibagi antara halaman detail dan tab Bookmark
/// (BC-05, BC-06). Urutan: terbaru di atas.
class BookmarkController extends ChangeNotifier {
  BookmarkController([this._store = const BookmarkStore()]);

  final BookmarkStore _store;
  List<Bookmark> _items = const [];

  List<Bookmark> get items => _items;

  Future<void> load() async {
    _items = _sorted(await _store.load());
    notifyListeners();
  }

  bool isSaved(int surah, int ayat) =>
      _items.any((b) => b.isSame(surah, ayat));

  /// Simpan bila belum ada, hapus bila sudah. True = sekarang tersimpan.
  Future<bool> toggle(int surah, int ayat, {DateTime? at}) async {
    if (isSaved(surah, ayat)) {
      await remove(surah, ayat);
      return false;
    }
    await _commit([
      Bookmark(surah: surah, ayat: ayat, savedAt: at ?? DateTime.now()),
      ..._items,
    ]);
    return true;
  }

  Future<void> remove(int surah, int ayat) =>
      _commit([
        for (final b in _items)
          if (!b.isSame(surah, ayat)) b,
      ]);

  /// Gabungkan [incoming] (impor cadangan); ayat yang sudah ada tidak ditimpa.
  /// Mengembalikan jumlah yang bertambah.
  Future<int> merge(List<Bookmark> incoming) async {
    final fresh = <Bookmark>[];
    for (final b in incoming) {
      if (!isSaved(b.surah, b.ayat) &&
          !fresh.any((f) => f.isSame(b.surah, b.ayat))) {
        fresh.add(b);
      }
    }
    if (fresh.isNotEmpty) await _commit([..._items, ...fresh]);
    return fresh.length;
  }

  /// Berapa ayat dari [incoming] yang belum ada di perangkat ini.
  int countNew(List<Bookmark> incoming) => {
    for (final b in incoming)
      if (!isSaved(b.surah, b.ayat)) '${b.surah}:${b.ayat}',
  }.length;

  Future<void> _commit(List<Bookmark> next) async {
    _items = _sorted(next);
    notifyListeners();
    await _store.save(_items);
  }

  // sort() tidak stabil; urutan sisipan dipertahankan lewat indeks.
  List<Bookmark> _sorted(List<Bookmark> list) {
    final indexed = list.indexed.toList()
      ..sort((a, b) {
        final byTime = b.$2.savedAt.compareTo(a.$2.savedAt);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    return [for (final e in indexed) e.$2];
  }
}
