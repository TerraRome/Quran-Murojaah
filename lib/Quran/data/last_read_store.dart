import 'package:shared_preferences/shared_preferences.dart';

import '../application/last_read.dart';

/// Menyimpan posisi baca terakhir secara lokal (QR-07).
///
/// Persistensi memakai [SharedPreferences] — cukup untuk satu posisi baca
/// terakhir, tanpa ketergantungan pada module storage lain.
class LastReadStore {
  const LastReadStore();

  static const _keySurah = 'quran_last_read_surah';
  static const _keyVerse = 'quran_last_read_verse';

  Future<LastRead?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final surah = prefs.getInt(_keySurah);
    final verse = prefs.getInt(_keyVerse);
    if (surah == null || verse == null) {
      return null;
    }
    return LastRead(surahNumber: surah, verseNumber: verse);
  }

  Future<void> save(LastRead lastRead) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySurah, lastRead.surahNumber);
    await prefs.setInt(_keyVerse, lastRead.verseNumber);
  }
}
