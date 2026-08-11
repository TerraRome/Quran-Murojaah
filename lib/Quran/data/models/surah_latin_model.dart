/// Model ringan untuk parse response `/surat/{nomor}` dari API equran.id.
///
/// Hanya mengambil [nomorAyat] dan [teksLatin] — field lain diabaikan
/// karena tujuan model ini hanya untuk prefetch transliteration.
class SurahLatinModel {
  const SurahLatinModel({required this.verses});

  /// Map nomorAyat (1-based) → teksLatin.
  final Map<int, String> verses;

  factory SurahLatinModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) return const SurahLatinModel(verses: {});

    final ayat = data['ayat'] as List<dynamic>? ?? [];
    final verses = <int, String>{};
    for (final item in ayat) {
      final map = item as Map<String, dynamic>;
      final nomor = map['nomorAyat'] as int?;
      final latin = map['teksLatin'] as String?;
      if (nomor != null && latin != null) {
        verses[nomor] = latin;
      }
    }
    return SurahLatinModel(verses: verses);
  }
}
