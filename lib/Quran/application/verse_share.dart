/// Teks ayat siap bagi (BC-07): Arab, latin (opsional), terjemahan, lalu
/// rujukan "QS. Al-Baqarah: 255". Bagian kosong dilewati.
String buildVerseShareText({
  required String surahName,
  required int ayat,
  required String arabic,
  required String translation,
  String transliteration = '',
  bool showLatin = true,
}) {
  return [
    arabic,
    if (showLatin && transliteration.isNotEmpty) transliteration,
    if (translation.isNotEmpty) translation,
    'QS. $surahName: $ayat',
  ].join('\n\n');
}
