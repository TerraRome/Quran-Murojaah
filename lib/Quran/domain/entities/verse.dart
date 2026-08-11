/// Representasi satu ayat Al-Quran.
///
/// Memiliki tiga representasi teks sesuai MUROJAAH_RULES:
/// - [arabic]         : source of truth, teks Uthmani asli
/// - [transliteration]: representasi Latin dari API (teksLatin)
/// - [normalizedText] : versi mesin untuk matching STT, pre-computed
class Verse {
  const Verse({
    required this.number,
    required this.numberInSurah,
    required this.arabic,
    required this.translation,
    this.transliteration = '',
    this.normalizedText = '',
  });

  /// Nomor ayat global (1..6236).
  final int number;

  /// Nomor ayat dalam surah (1..totalVerses).
  final int numberInSurah;

  /// Teks ayat dalam bahasa Arab (Uthmani) — source of truth.
  /// Tidak boleh dimodifikasi. Termasuk prefix basmala bila ada.
  final String arabic;

  /// Terjemahan ayat dalam Bahasa Indonesia.
  final String translation;

  /// Transliterasi Latin canonical dari API equran.id (`teksLatin`).
  /// Contoh: "Wal-qur'ānil-ḥakīm(i)."
  /// Kosong ('') jika belum di-fetch atau tidak tersedia.
  final String transliteration;

  /// Normalized text untuk matching mesin — pre-computed dari [transliteration].
  /// Lowercase, tanpa tanda baca, tanpa diacritic Latin, hyphen→spasi.
  /// Contoh: "wal quranilhakimi"
  /// Kosong ('') jika [transliteration] belum tersedia.
  final String normalizedText;

  /// Teks Arab untuk ditampilkan: strip prefix basmala untuk surah selain 1
  /// (Al-Fatihah). Surah 1 menampilkan basmala sebagai ayat tersendiri.
  /// Surah 9 tidak memiliki basmala — tidak ada yang di-strip.
  ///
  /// Deteksi via 4 kata pertama yang dinormalisasi (bukan string literal)
  /// karena urutan diacritic di data JSON bisa berbeda dengan source code.
  String displayArabic(int surahNumber) {
    if (surahNumber == 1) return arabic;
    final words = arabic.trimLeft().split(' ');
    if (words.length > 4) {
      final firstFour = _normalizeSimple(words.take(4).join(' '));
      if (firstFour == 'بسم الله الرحمن الرحيم') {
        return words.skip(4).join(' ').trimLeft();
      }
    }
    return arabic;
  }

  /// Kembalikan salinan verse dengan transliteration + normalizedText baru.
  /// Digunakan saat data transliteration tiba dari cache/API setelah
  /// verse sudah di-parse dari JSON aset.
  Verse withTransliteration({
    required String transliteration,
    required String normalizedText,
  }) {
    return Verse(
      number: number,
      numberInSurah: numberInSurah,
      arabic: arabic,
      translation: translation,
      transliteration: transliteration,
      normalizedText: normalizedText,
    );
  }

  /// Normalisasi ringan khusus deteksi basmala: buang diacritic dan
  /// normalisasi varian alif. Tidak perlu sekompleks ArabicMatcher.
  static String _normalizeSimple(String s) {
    s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
    s = s.replaceAll('\u0671', '\u0627'); // ٱ → ا
    s = s.replaceAll('\u0622', '\u0627'); // آ → ا
    s = s.replaceAll('\u0623', '\u0627'); // أ → ا
    s = s.replaceAll('\u0625', '\u0627'); // إ → ا
    return s.trim();
  }

  factory Verse.fromJson(Map<String, dynamic> json) => Verse(
        number: json['number'] as int,
        numberInSurah: json['numberInSurah'] as int,
        arabic: json['arabic'] as String,
        translation: json['translation'] as String,
        // transliteration & normalizedText tidak ada di JSON aset lokal —
        // akan di-inject oleh TransliterationPrefetchService saat boot.
      );
}
