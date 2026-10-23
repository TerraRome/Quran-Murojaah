import 'dart:async';

import '../progress/progress_controller.dart';
import '../progress/record_result.dart';
import 'recite_session_controller.dart';

/// Mencatat ayat yang sudah tuntas dari satu sesi murojaah ke log progres.
///
/// Dipisah dari halaman supaya bisa diuji tanpa mesin ASR dan tanpa perangkat.
/// Satu instance hidup selama satu sesi; [_recorded] memastikan ayat yang sama
/// tidak tercatat dua kali walau pencatatan dipicu berkali-kali (sesi berhenti,
/// surah tamat, aplikasi masuk background).
class ReciteProgressRecorder {
  ReciteProgressRecorder({
    required this.progress,
    required this.surahNumber,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final MurojaahProgressController? progress;
  final int surahNumber;

  /// Sumber waktu tunggal untuk semua entri sesi ini.
  ///
  /// Disuntikkan supaya test tidak bergantung pada jam perangkat (dan tidak
  /// gagal saat kalender berganti hari).
  final DateTime Function() _clock;

  final Set<int> _recorded = {};
  RecordResult _result = RecordResult.none;

  /// Ayat (0-based) yang sudah tercatat — untuk test dan diagnostik.
  Set<int> get recorded => Set.unmodifiable(_recorded);

  /// Jumlah ayat yang sudah tercatat pada sesi ini.
  int get recordedCount => _recorded.length;

  /// Gabungan hasil pencatatan sesi ini sejauh ini.
  RecordResult get result => _result;

  /// Catat rentang ayat berurutan yang sudah terbaca penuh.
  ///
  /// Tidak melakukan apa pun bila [progress] null atau belum ada ayat. Akurasi
  /// sesi ikut dicatat sebagai satu angka untuk seluruh rentang. Hasil
  /// dikembalikan sekaligus diakumulasi di [result], sehingga pemanggil yang
  /// memicu pencatatan berkali-kali tetap melihat "streak naik" dari entri
  /// pertama yang menyebabkannya.
  Future<RecordResult> record(ReciteSessionController session) async {
    final target = progress;
    if (target == null || session.verses.isEmpty) return _result;

    final accuracy = session.accuracy;
    var start = -1;

    Future<void> flush(int endExclusive) async {
      if (start < 0) return;
      final outcome = await target.record(
        surahNumber: surahNumber,
        fromVerse: start + 1,
        toVerse: endExclusive,
        accuracy: accuracy,
        at: _clock(),
      );
      _result = _result + outcome;
      start = -1;
    }

    for (var verse = 0; verse < session.verses.length; verse++) {
      final done = session.isVerseComplete(verse) && !_recorded.contains(verse);
      if (done) {
        _recorded.add(verse);
        if (start < 0) start = verse;
      } else if (start >= 0) {
        await flush(verse);
      }
    }
    await flush(session.verses.length);
    return _result;
  }
}
