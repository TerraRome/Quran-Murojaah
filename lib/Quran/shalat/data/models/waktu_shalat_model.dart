import '../../domain/entities/waktu_shalat.dart';

/// JSON model untuk waktu shalat satu hari.
class WaktuShalatModel {
  const WaktuShalatModel({
    required this.tanggal,
    required this.tanggalLengkap,
    required this.hari,
    required this.imsak,
    required this.subuh,
    required this.terbit,
    required this.dhuha,
    required this.dzuhur,
    required this.ashar,
    required this.maghrib,
    required this.isya,
  });

  final int tanggal;
  final String tanggalLengkap;
  final String hari;
  final String imsak;
  final String subuh;
  final String terbit;
  final String dhuha;
  final String dzuhur;
  final String ashar;
  final String maghrib;
  final String isya;

  factory WaktuShalatModel.fromJson(Map<String, dynamic> json) {
    return WaktuShalatModel(
      tanggal: (json['tanggal'] as num).toInt(),
      tanggalLengkap: json['tanggal_lengkap'] as String,
      hari: json['hari'] as String,
      imsak: json['imsak'] as String,
      subuh: json['subuh'] as String,
      terbit: json['terbit'] as String,
      dhuha: json['dhuha'] as String,
      dzuhur: json['dzuhur'] as String,
      ashar: json['ashar'] as String,
      maghrib: json['maghrib'] as String,
      isya: json['isya'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'tanggal': tanggal,
        'tanggal_lengkap': tanggalLengkap,
        'hari': hari,
        'imsak': imsak,
        'subuh': subuh,
        'terbit': terbit,
        'dhuha': dhuha,
        'dzuhur': dzuhur,
        'ashar': ashar,
        'maghrib': maghrib,
        'isya': isya,
      };

  WaktuShalat toDomain() => WaktuShalat(
        tanggal: tanggal,
        tanggalLengkap: tanggalLengkap,
        hari: hari,
        imsak: imsak,
        subuh: subuh,
        terbit: terbit,
        dhuha: dhuha,
        dzuhur: dzuhur,
        ashar: ashar,
        maghrib: maghrib,
        isya: isya,
      );
}
