/// Normalisasi transliterasi Latin untuk pencocokan.
///
/// Dipisahkan dari pipeline Murojaah lama: hanya bagian yang masih dipakai
/// oleh [TransliterationPrefetchService].
library latin_normalizer;

/// Normalisasi teks transliterasi Latin ke bentuk ASCII bersih.
String normalizeLatin(String latin) {
  var s = latin.toLowerCase();
  // Strip notasi waqf/wasl seperti (a), (i), (u).
  s = s.replaceAll(RegExp(r'\([aiu]\)'), '');
  // Diacritic Latin → ASCII.
  s = s.replaceAll('ā', 'a').replaceAll('ī', 'i').replaceAll('ū', 'u');
  s = s.replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('ó', 'o');
  s = s.replaceAll('ḥ', 'h').replaceAll('ṣ', 's').replaceAll('ṭ', 't');
  s = s.replaceAll('ẓ', 'z').replaceAll('ḍ', 'd').replaceAll('ġ', 'g');
  s = s.replaceAll('ż', 'z'); // dzal (ذ)
  s = s.replaceAll('ṡ', 's'); // tsa (ث)
  s = s.replaceAll('ʿ', '').replaceAll('ʾ', '').replaceAll("'", '');
  s = s.replaceAll('\u2018', '').replaceAll('\u2019', '');
  s = s.replaceAll('\u2026', '');
  // Hyphen & dash → spasi.
  s = s.replaceAll(RegExp(r'[-\u2013\u2014]'), ' ');
  // Strip tanda baca.
  s = s.replaceAll(RegExp(r'''[.,;:!?"“”‘’«»]'''), '');
  // Normalisasi spasi.
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}
