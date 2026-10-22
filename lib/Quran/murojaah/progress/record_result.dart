/// Hasil satu pencatatan aktivitas.
///
/// Dihitung dengan membandingkan snapshot sebelum dan sesudah entri disimpan,
/// memakai satu nilai waktu yang sama. Tidak ada angka yang disimpan terpisah —
/// semua tetap turunan log.
class RecordResult {
  const RecordResult({
    this.xpGained = 0,
    this.streakIncreased = false,
    this.goalJustReached = false,
    this.newStreak = 0,
    this.newLevel = 1,
    this.leveledUp = false,
  });

  /// Tidak ada yang tercatat (rentang tidak valid atau sesi kosong).
  static const none = RecordResult();

  /// XP yang benar-benar didapat entri ini — nol bila akurasi di bawah ambang,
  /// batas harian habis, atau ayat itu sudah memberi XP hari ini.
  final int xpGained;

  /// Hari ini baru menjadi aktif karena entri ini. Sesi kedua di hari yang sama
  /// tidak pernah memunculkan "streak naik" lagi.
  final bool streakIncreased;

  /// Target harian baru pertama kali tercapai oleh entri ini.
  final bool goalJustReached;

  final int newStreak;
  final int newLevel;
  final bool leveledUp;

  /// Gabungan beberapa pencatatan dalam satu sesi.
  ///
  /// XP dijumlah; penanda "naik"/"tercapai"/"level" tidak pernah hilang karena
  /// satu entri berikutnya; angka terbaru (streak, level) menang.
  RecordResult operator +(RecordResult other) => RecordResult(
    xpGained: xpGained + other.xpGained,
    streakIncreased: streakIncreased || other.streakIncreased,
    goalJustReached: goalJustReached || other.goalJustReached,
    newStreak: other.newStreak > newStreak ? other.newStreak : newStreak,
    newLevel: other.newLevel > newLevel ? other.newLevel : newLevel,
    leveledUp: leveledUp || other.leveledUp,
  );

  @override
  String toString() =>
      'RecordResult(xp: $xpGained, streakIncreased: $streakIncreased, '
      'goalJustReached: $goalJustReached, streak: $newStreak, '
      'level: $newLevel, leveledUp: $leveledUp)';
}
