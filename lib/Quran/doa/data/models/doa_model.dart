import '../../domain/entities/doa.dart';

/// JSON model untuk satu doa dari API equran.id/api/doa.
class DoaModel {
  const DoaModel({
    required this.id,
    required this.grup,
    required this.nama,
    required this.ar,
    required this.tr,
    required this.idn,
    required this.tentang,
    required this.tag,
  });

  final int id;
  final String grup;
  final String nama;
  final String ar;
  final String tr;
  final String idn;
  final String tentang;
  final List<String> tag;

  factory DoaModel.fromJson(Map<String, dynamic> json) {
    final rawTag = json['tag'];
    final List<String> tagList;
    if (rawTag is List) {
      tagList = rawTag.map((e) => e.toString()).toList();
    } else {
      tagList = [];
    }

    return DoaModel(
      id: (json['id'] as num).toInt(),
      grup: (json['grup'] as String?) ?? '',
      nama: (json['nama'] as String?) ?? '',
      ar: (json['ar'] as String?) ?? '',
      tr: (json['tr'] as String?) ?? '',
      idn: (json['idn'] as String?) ?? '',
      tentang: (json['tentang'] as String?) ?? '',
      tag: tagList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'grup': grup,
        'nama': nama,
        'ar': ar,
        'tr': tr,
        'idn': idn,
        'tentang': tentang,
        'tag': tag,
      };

  Doa toDomain() => Doa(
        id: id,
        grup: grup,
        nama: nama,
        ar: ar,
        tr: tr,
        idn: idn,
        tentang: tentang,
        tag: tag,
      );

  static DoaModel fromDomain(Doa doa) => DoaModel(
        id: doa.id,
        grup: doa.grup,
        nama: doa.nama,
        ar: doa.ar,
        tr: doa.tr,
        idn: doa.idn,
        tentang: doa.tentang,
        tag: doa.tag,
      );
}
