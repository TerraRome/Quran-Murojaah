import 'activity_entry.dart';

/// Status hafalan satu surah pada peta 114 surah.
///
/// Label dipakai apa adanya di UI; ikon dipilih di widget supaya lapisan data
/// tidak bergantung pada Flutter Material.
enum HafalanStatus {
  belumMulai('Belum mulai'),
  sedang('Sedang'),
  lancar('Lancar');

  const HafalanStatus(this.label);

  final String label;
}

/// Ringkasan hafalan satu surah, dihitung sekali dari log.
class HafalanSurah {
  const HafalanSurah({
    required this.surahNumber,
    required this.totalVerses,
    required this.versesCovered,
    required this.accuracy,
    required this.status,
  });

  final int surahNumber;

  /// Jumlah ayat surah dari sumber yang sudah ada; 0 = belum diketahui.
  final int totalVerses;

  /// Ayat yang pernah dimurojaah (gabungan rentang, tanpa dobel).
  final int versesCovered;

  /// Akurasi terbaru terendah di antara ayat surah ini; null = tak terukur.
  ///
  /// Dipakai sebagai angka ringkas "seberapa lancar" — satu ayat yang turun
  /// akan terlihat di sini, bukan tertutup rata-rata.
  final double? accuracy;

  final HafalanStatus status;

  int get remaining => (totalVerses - versesCovered).clamp(0, totalVerses);

  double get fraction =>
      totalVerses <= 0 ? 0 : (versesCovered / totalVerses).clamp(0.0, 1.0);
}

/// Peta hafalan 114 surah.
///
/// Dihitung **satu kali** dari seluruh log ([compute]) lalu disimpan oleh
/// pemanggil (lihat `MurojaahProgressController.hafalan`), sehingga daftar 114
/// baris tidak pernah memindai log sendiri-sendiri saat build.
class HafalanMap {
  const HafalanMap._(this.surahs, this._byNumber);

  static const surahCount = 114;

  /// Akurasi minimal **tiap ayat** agar surah yang sudah tamat disebut lancar.
  ///
  /// Sama dengan ambang XP murojaah: satu angka, satu arti.
  static const lancarAccuracy = ActivityEntry.xpAccuracyThreshold;

  final List<HafalanSurah> surahs;
  final Map<int, HafalanSurah> _byNumber;

  HafalanSurah of(int surahNumber) =>
      _byNumber[surahNumber] ??
      HafalanSurah(
        surahNumber: surahNumber,
        totalVerses: 0,
        versesCovered: 0,
        accuracy: null,
        status: HafalanStatus.belumMulai,
      );

  int get lancarCount => _count(HafalanStatus.lancar);

  int get sedangCount => _count(HafalanStatus.sedang);

  int get belumMulaiCount => _count(HafalanStatus.belumMulai);

  int _count(HafalanStatus status) =>
      surahs.where((s) => s.status == status).length;

  /// Satu lintasan log: akurasi **terbaru per ayat**, lalu status per surah.
  ///
  /// Ayat dianggap tuntas bila pernah dimurojaah. Akurasi tiap ayat diambil
  /// dari entri paling baru yang mencakup ayat itu, jadi sesi ulang pada satu
  /// ayat saja bisa menaikkan atau menurunkan status surah.
  ///
  /// [verseCount] disuntikkan dari daftar surah yang sudah dimuat — tidak ada
  /// sumber jumlah ayat kedua.
  factory HafalanMap.compute(
    List<ActivityEntry> entries, {
    int Function(int surahNumber)? verseCount,
    int surahCount = HafalanMap.surahCount,
  }) {
    // surah → (ayat → akurasi terbaru). Null = tidak terukur.
    final bySurah = <int, Map<int, double?>>{};
    final newest = <int, Map<int, DateTime>>{};

    for (final entry in entries) {
      if (entry.type != ActivityType.murojaah) continue;
      if (entry.surahNumber <= ActivityEntry.noSurah) continue;
      final verses = bySurah.putIfAbsent(entry.surahNumber, () => {});
      final stamps = newest.putIfAbsent(entry.surahNumber, () => {});
      for (var verse = entry.fromVerse; verse <= entry.toVerse; verse++) {
        final previous = stamps[verse];
        if (previous != null && entry.at.isBefore(previous)) continue;
        stamps[verse] = entry.at;
        verses[verse] = entry.accuracy;
      }
    }

    final list = <HafalanSurah>[];
    for (var number = 1; number <= surahCount; number++) {
      final total = verseCount?.call(number) ?? 0;
      final verses = bySurah[number] ?? const <int, double?>{};
      final covered = verses.length;
      final complete = total > 0 && covered >= total;
      final lowest = _lowestAccuracy(verses.values);
      final allGood = lowest == null || lowest >= lancarAccuracy;
      final status = covered == 0
          ? HafalanStatus.belumMulai
          : (complete && allGood ? HafalanStatus.lancar : HafalanStatus.sedang);
      list.add(
        HafalanSurah(
          surahNumber: number,
          totalVerses: total,
          versesCovered: covered,
          accuracy: lowest,
          status: status,
        ),
      );
    }

    return HafalanMap._(List.unmodifiable(list), {
      for (final surah in list) surah.surahNumber: surah,
    });
  }

  /// Akurasi terendah yang terukur; null bila tak satu pun terukur.
  static double? _lowestAccuracy(Iterable<double?> values) {
    double? lowest;
    for (final value in values) {
      if (value == null) continue;
      if (lowest == null || value < lowest) lowest = value;
    }
    return lowest;
  }
}
