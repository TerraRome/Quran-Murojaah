/// Tafsir (penjelasan/interpretasi) satu ayat Al-Quran.
///
/// Data dari API equran.id v2 endpoint `/tafsir/{nomor}`.
/// Teks tafsir dapat mengandung tag HTML sederhana (`<i>`, `<b>`, dll).
class Tafsir {
  const Tafsir({
    required this.ayat,
    required this.teks,
  });

  /// Nomor ayat dalam surah (1-based).
  final int ayat;

  /// Teks tafsir lengkap. Dapat mengandung HTML tag (`<i>`, `<b>`, dll).
  final String teks;

  factory Tafsir.fromJson(Map<String, dynamic> json) => Tafsir(
        ayat: json['ayat'] as int,
        teks: json['teks'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Tafsir && other.ayat == ayat;

  @override
  int get hashCode => ayat.hashCode;

  @override
  String toString() => 'Tafsir(ayat=$ayat)';
}
