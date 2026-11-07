/// Satu ayat yang disimpan pengguna (BC-05).
class Bookmark {
  const Bookmark({
    required this.surah,
    required this.ayat,
    required this.savedAt,
  });

  final int surah;
  final int ayat;
  final DateTime savedAt;

  bool isSame(int surah, int ayat) => this.surah == surah && this.ayat == ayat;

  Map<String, Object?> toJson() => {
    'surah': surah,
    'ayat': ayat,
    'savedAt': savedAt.toUtc().toIso8601String(),
  };

  /// Null bila bentuknya tidak dikenali — pemanggil melewati entri itu.
  static Bookmark? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final surah = raw['surah'];
    final ayat = raw['ayat'];
    final savedAt = DateTime.tryParse('${raw['savedAt']}');
    if (surah is! int || ayat is! int || savedAt == null) return null;
    if (surah < 1 || surah > 114 || ayat < 1) return null;
    return Bookmark(surah: surah, ayat: ayat, savedAt: savedAt);
  }
}
