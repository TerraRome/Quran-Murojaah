import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/surah.dart';

/// Data source aset lokal Al-Quran.
///
/// Membaca file `assets/quran/quran.json` dari bundle dan mem-parse-nya
/// menjadi list [Surah]. Hasil di-cache di memori supaya hanya di-parse sekali
/// (file berukuran ~2.9MB). Mengikuti catatan "File IO" (Second Brain 07).
class QuranAssetDataSource {
  QuranAssetDataSource({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const _assetPath = 'assets/quran/quran.json';

  List<Surah>? _cache;

  /// Memuat & mem-parse seluruh surah. Mengembalikan `null` jika gagal.
  Future<List<Surah>?> loadSurahs() async {
    if (_cache != null) {
      return _cache;
    }
    try {
      final raw = await _bundle.loadString(_assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final surahs = (decoded['surahs'] as List<dynamic>)
          .map((json) => Surah.fromJson(json as Map<String, dynamic>))
          .toList();
      _cache = surahs;
      return surahs;
    } on FormatException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Ambil satu surah dari cache (tanpa load ulang).
  Surah? surahByNumber(int number) {
    final surahs = _cache;
    if (surahs == null) {
      return null;
    }
    return surahs.where((surah) => surah.number == number).firstOrNull;
  }
}
