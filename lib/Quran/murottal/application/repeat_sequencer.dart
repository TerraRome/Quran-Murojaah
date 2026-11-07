/// Pilihan ulang & jeda untuk pemutaran murottal (BL-02..BL-04).
enum RepeatKind { off, ayat, range }

/// Pengaturan ulang. [count] = total putaran; [infinite] (0) = terus-menerus.
class RepeatSettings {
  const RepeatSettings({
    this.mode = RepeatKind.off,
    this.count = 3,
    this.rangeStart = 1,
    this.rangeEnd = 1,
    this.gapSeconds = 0,
  });

  static const int infinite = 0;
  static const List<int> counts = [1, 3, 5, 10, infinite];
  static const List<int> gaps = [0, 2, 5];

  final RepeatKind mode;
  final int count;
  final int rangeStart;
  final int rangeEnd;
  final int gapSeconds;

  RepeatSettings copyWith({
    RepeatKind? mode,
    int? count,
    int? rangeStart,
    int? rangeEnd,
    int? gapSeconds,
  }) =>
      RepeatSettings(
        mode: mode ?? this.mode,
        count: count ?? this.count,
        rangeStart: rangeStart ?? this.rangeStart,
        rangeEnd: rangeEnd ?? this.rangeEnd,
        gapSeconds: gapSeconds ?? this.gapSeconds,
      );

  @override
  bool operator ==(Object other) =>
      other is RepeatSettings &&
      other.mode == mode &&
      other.count == count &&
      other.rangeStart == rangeStart &&
      other.rangeEnd == rangeEnd &&
      other.gapSeconds == gapSeconds;

  @override
  int get hashCode => Object.hash(mode, count, rangeStart, rangeEnd, gapSeconds);
}

/// Langkah berikutnya setelah satu ayat selesai diputar.
sealed class NextStep {
  const NextStep();
}

/// Berhenti (idle).
class StopPlayback extends NextStep {
  const StopPlayback();
}

/// Putar [ayat] di [surah] yang sama setelah menunggu [gap].
/// Jika [ayat] sama dengan ayat yang baru selesai, berarti diulang.
class PlayAyat extends NextStep {
  const PlayAyat(this.ayat, {this.gap = Duration.zero});
  final int ayat;
  final Duration gap;
}

/// Lanjut ke ayat 1 surah [surah] (lanjut otomatis).
class PlaySurah extends NextStep {
  const PlaySurah(this.surah);
  final int surah;
}

/// Logika murni "apa yang diputar berikutnya" — tanpa player, bisa diuji.
///
/// Mode ulang aktif selalu menang atas lanjut otomatis ke surah berikutnya.
class RepeatSequencer {
  static const int lastSurah = 114;

  RepeatSettings settings = const RepeatSettings();
  int _pass = 0;

  /// Mulai hitungan dari awal (putaran baru atau pengaturan berubah).
  void reset() => _pass = 0;

  bool get _more => settings.count == RepeatSettings.infinite || _pass < settings.count;

  Duration get _gap => Duration(seconds: settings.gapSeconds);

  NextStep onAyatCompleted({
    required int surah,
    required int ayat,
    required int totalAyat,
    required bool isFullSurah,
    required bool autoNextSurah,
  }) {
    switch (settings.mode) {
      case RepeatKind.ayat:
        _pass++;
        if (_more) return PlayAyat(ayat, gap: _gap);
        _pass = 0;
        return const StopPlayback();
      case RepeatKind.range:
        final end = settings.rangeEnd.clamp(1, totalAyat);
        final start = settings.rangeStart.clamp(1, end);
        if (ayat < end) return PlayAyat(ayat + 1);
        _pass++;
        if (_more) return PlayAyat(start, gap: _gap);
        _pass = 0;
        return const StopPlayback();
      case RepeatKind.off:
        if (ayat < totalAyat) return PlayAyat(ayat + 1);
        if (isFullSurah && autoNextSurah && surah < lastSurah) {
          return PlaySurah(surah + 1);
        }
        return const StopPlayback();
    }
  }
}
