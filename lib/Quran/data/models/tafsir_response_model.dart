import '../../domain/entities/tafsir.dart';

/// Model response dari API equran.id v2 endpoint `/tafsir/{nomor}`.
class TafsirResponseModel {
  const TafsirResponseModel({
    required this.nomor,
    required this.tafsir,
  });

  /// Nomor surah (1..114).
  final int nomor;

  /// List tafsir per ayat.
  final List<Tafsir> tafsir;

  factory TafsirResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final tafsirRaw = data['tafsir'] as List<dynamic>? ?? [];
    return TafsirResponseModel(
      nomor: data['nomor'] as int,
      tafsir: tafsirRaw
          .map((e) => Tafsir.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
