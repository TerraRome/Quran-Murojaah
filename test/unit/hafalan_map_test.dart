import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/progress/activity_entry.dart';
import 'package:quran/Quran/murojaah/progress/hafalan_map.dart';

ActivityEntry _murojaah(
  int surah,
  int from,
  int to, {
  double? accuracy,
  int minute = 0,
}) => ActivityEntry(
  at: DateTime(2026, 10, 22, 9, minute),
  surahNumber: surah,
  fromVerse: from,
  toVerse: to,
  type: ActivityType.murojaah,
  accuracy: accuracy,
);

/// Tiga surah: 1 (7 ayat), 2 (5 ayat), 3 (4 ayat).
int _verseCount(int surah) => switch (surah) {
  1 => 7,
  2 => 5,
  3 => 4,
  _ => 0,
};

void main() {
  group('status', () {
    test('tiga status: belum mulai, sedang, lancar', () {
      final map = HafalanMap.compute([
        _murojaah(1, 1, 7, accuracy: 0.95),
        _murojaah(2, 1, 2, accuracy: 0.9),
      ], verseCount: _verseCount);

      expect(map.of(1).status, HafalanStatus.lancar);
      expect(map.of(2).status, HafalanStatus.sedang);
      expect(map.of(3).status, HafalanStatus.belumMulai);
      expect(map.lancarCount, 1);
      expect(map.sedangCount, 1);
      expect(map.belumMulaiCount, HafalanMap.surahCount - 2);
    });

    test('satu ayat kurang belum lancar', () {
      final map = HafalanMap.compute([
        _murojaah(1, 1, 6, accuracy: 0.99),
      ], verseCount: _verseCount);

      expect(map.of(1).versesCovered, 6);
      expect(map.of(1).remaining, 1);
      expect(map.of(1).status, HafalanStatus.sedang);
    });

    test('tamat tapi akurasi rendah tetap sedang', () {
      final map = HafalanMap.compute([
        _murojaah(1, 1, 7, accuracy: 0.6),
      ], verseCount: _verseCount);

      expect(map.of(1).status, HafalanStatus.sedang);
    });

    test(
      'akurasi terbaru per ayat: ayat 1-6 0.3 lalu ayat 7 0.95 → sedang',
      () {
        final map = HafalanMap.compute([
          _murojaah(1, 1, 6, accuracy: 0.3, minute: 0),
          _murojaah(1, 7, 7, accuracy: 0.95, minute: 10),
        ], verseCount: _verseCount);

        expect(map.of(1).versesCovered, 7);
        expect(map.of(1).accuracy, 0.3);
        expect(map.of(1).status, HafalanStatus.sedang);
      },
    );

    test('sesi ulang rendah pada satu ayat menurunkan lancar → sedang', () {
      final map = HafalanMap.compute([
        _murojaah(1, 1, 7, accuracy: 0.95, minute: 0),
        _murojaah(1, 4, 4, accuracy: 0.5, minute: 10),
      ], verseCount: _verseCount);

      expect(map.of(1).versesCovered, 7);
      expect(map.of(1).accuracy, 0.5);
      expect(map.of(1).status, HafalanStatus.sedang);
    });

    test('sesi ulang tinggi mengembalikan sedang → lancar', () {
      final map = HafalanMap.compute([
        _murojaah(1, 1, 7, accuracy: 0.95, minute: 0),
        _murojaah(1, 4, 4, accuracy: 0.5, minute: 10),
        _murojaah(1, 4, 4, accuracy: 0.97, minute: 20),
      ], verseCount: _verseCount);

      expect(map.of(1).accuracy, 0.95);
      expect(map.of(1).status, HafalanStatus.lancar);
    });

    test('entri terbaru menimpa akurasi entri lama', () {
      final map = HafalanMap.compute([
        _murojaah(1, 1, 7, accuracy: 0.5, minute: 0),
        _murojaah(1, 1, 7, accuracy: 0.95, minute: 10),
      ], verseCount: _verseCount);

      expect(map.of(1).accuracy, 0.95);
      expect(map.of(1).status, HafalanStatus.lancar);

      final turun = HafalanMap.compute([
        _murojaah(1, 1, 7, accuracy: 0.95, minute: 0),
        _murojaah(1, 1, 7, accuracy: 0.4, minute: 10),
      ], verseCount: _verseCount);

      expect(turun.of(1).accuracy, 0.4);
      expect(turun.of(1).status, HafalanStatus.sedang);
    });

    test('rentang bertumpang tindih tidak menghitung ayat dua kali', () {
      final map = HafalanMap.compute([
        _murojaah(1, 1, 4, accuracy: 0.95),
        _murojaah(1, 3, 7, accuracy: 0.95),
      ], verseCount: _verseCount);

      expect(map.of(1).versesCovered, 7);
      expect(map.of(1).status, HafalanStatus.lancar);
    });

    test('jenis selain murojaah dan entri doa tidak masuk peta', () {
      final map = HafalanMap.compute([
        ActivityEntry(
          at: DateTime(2026, 10, 22, 9),
          surahNumber: 1,
          fromVerse: 1,
          toVerse: 7,
          type: ActivityType.quranRead,
        ),
        ActivityEntry(
          at: DateTime(2026, 10, 22, 9),
          surahNumber: ActivityEntry.noSurah,
          fromVerse: 1,
          toVerse: 1,
          type: ActivityType.doa,
          refId: 'doa-1',
        ),
      ], verseCount: _verseCount);

      expect(map.of(1).status, HafalanStatus.belumMulai);
      expect(map.lancarCount, 0);
    });

    test('jumlah ayat tak diketahui: tidak pernah lancar', () {
      final map = HafalanMap.compute([_murojaah(1, 1, 7, accuracy: 0.99)]);

      expect(map.of(1).totalVerses, 0);
      expect(map.of(1).versesCovered, 7);
      expect(map.of(1).status, HafalanStatus.sedang);
    });
  });

  group('performa', () {
    test('5.000 entri dihitung sekali, di bawah 1 detik', () {
      final entries = [
        for (var i = 0; i < 5000; i++)
          _murojaah(
            (i % 114) + 1,
            (i % 20) + 1,
            (i % 20) + 1,
            accuracy: 0.95,
            minute: i,
          ),
      ];

      final watch = Stopwatch()..start();
      final map = HafalanMap.compute(entries, verseCount: _verseCount);
      watch.stop();

      expect(map.surahs.length, HafalanMap.surahCount);
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });
  });
}
