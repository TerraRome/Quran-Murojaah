import '../../domain/entities/jadwal_shalat.dart';
import 'waktu_shalat_model.dart';

/// JSON model untuk jadwal shalat satu bulan.
class JadwalShalatModel {
  const JadwalShalatModel({
    required this.provinsi,
    required this.kabkota,
    required this.bulan,
    required this.tahun,
    required this.bulanNama,
    required this.jadwal,
  });

  final String provinsi;
  final String kabkota;
  final int bulan;
  final int tahun;
  final String bulanNama;
  final List<WaktuShalatModel> jadwal;

  factory JadwalShalatModel.fromJson(Map<String, dynamic> json) {
    final jadwalList = (json['jadwal'] as List<dynamic>)
        .map((e) => WaktuShalatModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return JadwalShalatModel(
      provinsi: json['provinsi'] as String,
      kabkota: json['kabkota'] as String,
      bulan: (json['bulan'] as num).toInt(),
      tahun: (json['tahun'] as num).toInt(),
      bulanNama: json['bulan_nama'] as String,
      jadwal: jadwalList,
    );
  }

  Map<String, dynamic> toJson() => {
        'provinsi': provinsi,
        'kabkota': kabkota,
        'bulan': bulan,
        'tahun': tahun,
        'bulan_nama': bulanNama,
        'jadwal': jadwal.map((w) => w.toJson()).toList(),
      };

  JadwalShalat toDomain() => JadwalShalat(
        provinsi: provinsi,
        kabkota: kabkota,
        bulan: bulan,
        tahun: tahun,
        bulanNama: bulanNama,
        jadwal: jadwal.map((w) => w.toDomain()).toList(),
      );
}
