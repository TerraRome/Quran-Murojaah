/// Model response dari API equran.id v2 endpoint `/surat/{nomor}`.
///
/// Hanya field yang relevan untuk audio — bukan seluruh response.
class SurahAudioModel {
  const SurahAudioModel({
    required this.nomor,
    required this.audioFull,
    required this.ayat,
  });

  /// Nomor surah (1..114).
  final int nomor;

  /// URL audio full surah per qari. Key = qari ID ("01"–"06").
  final Map<String, String> audioFull;

  /// List audio per ayat.
  final List<AyatAudioModel> ayat;

  factory SurahAudioModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final audioFullRaw = data['audioFull'] as Map<String, dynamic>? ?? {};
    final ayatRaw = data['ayat'] as List<dynamic>? ?? [];
    return SurahAudioModel(
      nomor: data['nomor'] as int,
      audioFull: audioFullRaw.map((k, v) => MapEntry(k, v as String)),
      ayat: ayatRaw
          .map((e) => AyatAudioModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Ambil URL audio full surah untuk qari tertentu.
  String? audioFullUrl(String qariId) => audioFull[qariId];
}

/// Audio per ayat untuk satu qari.
class AyatAudioModel {
  const AyatAudioModel({
    required this.nomorAyat,
    required this.audio,
  });

  /// Nomor ayat dalam surah (1-based).
  final int nomorAyat;

  /// URL audio per ayat per qari. Key = qari ID ("01"–"06").
  final Map<String, String> audio;

  factory AyatAudioModel.fromJson(Map<String, dynamic> json) {
    final audioRaw = json['audio'] as Map<String, dynamic>? ?? {};
    return AyatAudioModel(
      nomorAyat: json['nomorAyat'] as int,
      audio: audioRaw.map((k, v) => MapEntry(k, v as String)),
    );
  }

  /// Ambil URL audio ayat untuk qari tertentu.
  String? audioUrl(String qariId) => audio[qariId];
}
