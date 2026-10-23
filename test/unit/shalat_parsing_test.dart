import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/shalat/data/models/jadwal_shalat_model.dart';
import 'package:quran/Quran/shalat/data/models/waktu_shalat_model.dart';

/// Bentuk response `data` dari POST https://equran.id/api/v2/shalat.
Map<String, dynamic> _sampleData() => {
      'provinsi': 'DKI Jakarta',
      'kabkota': 'KOTA JAKARTA PUSAT',
      'bulan': 10,
      'tahun': 2026,
      'bulan_nama': 'Oktober',
      'jadwal': [
        {
          'tanggal': 1,
          'tanggal_lengkap': '2026-10-01',
          'hari': 'Kamis',
          'imsak': '04:22',
          'subuh': '04:32',
          'terbit': '05:45',
          'dhuha': '06:13',
          'dzuhur': '11:53',
          'ashar': '15:16',
          'maghrib': '17:53',
          'isya': '19:06',
        },
        {
          'tanggal': 2,
          'tanggal_lengkap': '2026-10-02',
          'hari': 'Jumat',
          'imsak': '04:22',
          'subuh': '04:32',
          'terbit': '05:45',
          'dhuha': '06:13',
          'dzuhur': '11:53',
          'ashar': '15:16',
          'maghrib': '17:53',
          'isya': '19:06',
        },
      ],
    };

void main() {
  group('JadwalShalatModel.fromJson', () {
    test('memetakan field bulanan', () {
      final model = JadwalShalatModel.fromJson(_sampleData());

      expect(model.provinsi, 'DKI Jakarta');
      expect(model.kabkota, 'KOTA JAKARTA PUSAT');
      expect(model.bulan, 10);
      expect(model.tahun, 2026);
      expect(model.bulanNama, 'Oktober');
    });

    test('memetakan seluruh baris jadwal', () {
      final model = JadwalShalatModel.fromJson(_sampleData());

      expect(model.jadwal, hasLength(2));
      expect(model.jadwal.first.tanggalLengkap, '2026-10-01');
      expect(model.jadwal.last.tanggalLengkap, '2026-10-02');
    });

    test('baris pertama: 8 waktu verbatim', () {
      final w = JadwalShalatModel.fromJson(_sampleData()).jadwal.first;

      expect(w.tanggal, 1);
      expect(w.tanggalLengkap, '2026-10-01');
      expect(w.hari, 'Kamis');
      expect(w.imsak, '04:22');
      expect(w.subuh, '04:32');
      expect(w.terbit, '05:45');
      expect(w.dhuha, '06:13');
      expect(w.dzuhur, '11:53');
      expect(w.ashar, '15:16');
      expect(w.maghrib, '17:53');
      expect(w.isya, '19:06');
    });

    test('toJson round-trip sama dengan input', () {
      final data = _sampleData();

      expect(JadwalShalatModel.fromJson(data).toJson(), data);
    });

    test('toDomain meneruskan semua waktu', () {
      final domain = JadwalShalatModel.fromJson(_sampleData()).toDomain();

      expect(domain.jadwal, hasLength(2));
      expect(domain.jadwal.first.subuh, '04:32');
      expect(domain.jadwal.last.maghrib, '17:53');
    });
  });

  group('WaktuShalatModel.fromJson', () {
    test('menerima bulan/tahun bertipe num', () {
      final data = _sampleData();

      expect(
        () => JadwalShalatModel.fromJson({...data, 'bulan': 10.0}),
        returnsNormally,
      );
    });

    test('toJson round-trip satu baris', () {
      final row = _sampleData()['jadwal'] as List<dynamic>;
      final raw = row.first as Map<String, dynamic>;

      expect(WaktuShalatModel.fromJson(raw).toJson(), raw);
    });
  });
}
