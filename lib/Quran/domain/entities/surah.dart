import 'verse.dart';

enum RevelationType { meccan, medinan }

extension RevelationTypeX on RevelationType {
  String get label => switch (this) {
        RevelationType.meccan => 'Mekkah',
        RevelationType.medinan => 'Madinah',
      };
}

/// Representasi satu surah Al-Quran beserta ayat-ayatnya.
class Surah {
  const Surah({
    required this.number,
    required this.name,
    required this.transliteration,
    required this.translation,
    required this.revelationType,
    required this.totalVerses,
    required this.verses,
  });

  /// Nomor surah (1..114).
  final int number;

  /// Nama surah dalam bahasa Arab.
  final String name;

  /// Nama latin surah (contoh: "Al-Fatihah").
  final String transliteration;

  /// Arti nama surah dalam Bahasa Indonesia (contoh: "Pembukaan").
  final String translation;

  final RevelationType revelationType;

  final int totalVerses;

  final List<Verse> verses;

  bool get isMeccan => revelationType == RevelationType.meccan;

  factory Surah.fromJson(Map<String, dynamic> json) {
    final verses = (json['verses'] as List<dynamic>)
        .map((verse) => Verse.fromJson(verse as Map<String, dynamic>))
        .toList();
    final type = (json['revelationType'] as String?) ?? 'meccan';
    return Surah(
      number: json['number'] as int,
      name: json['name'] as String,
      transliteration: json['transliteration'] as String,
      translation: json['translation'] as String,
      revelationType: type == 'medinan' ? RevelationType.medinan : RevelationType.meccan,
      totalVerses: json['totalVerses'] as int? ?? verses.length,
      verses: verses,
    );
  }
}
