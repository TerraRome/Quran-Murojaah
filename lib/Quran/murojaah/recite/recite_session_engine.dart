import 'package:flutter/foundation.dart';
import 'package:recite_quran/recite_quran.dart';

/// Lifecycle of the on-device recitation engine for one surah.
enum ReciteMurojaahStatus {
  idle,
  preparing,
  downloadingModel,
  ready,
  listening,
  error,
}

/// Kontrak tipis yang dibutuhkan [ReciteSessionController].
///
/// `ReciteMurojaahService` adalah implementasi produksinya; test memakai fake.
/// Antarmuka ini hanya menyatakan apa yang sudah tersedia di service — tidak
/// menambah perilaku apa pun.
abstract class ReciteSessionEngine {
  List<QuranVerse> get verses;

  /// Offset kata global tiap ayat; panjang = jumlah ayat + 1.
  List<int> get wordAyahStarts;

  /// Fonem tiap kata global (0-based `wordId`).
  List<String> get wordPhonemes;

  String phonemesOf(int wordId);

  Stream<WordMatchedEvent> get wordEvents;

  Stream<String> get transcript;

  ValueListenable<ReciteMurojaahStatus> get status;
  ValueListenable<String?> get errorMessage;
  ValueListenable<double> get downloadProgress;

  Future<void> startListening();
  Future<void> stopListening();

  /// Kembalikan kursor pelacakan ke kata global [globalWordIndex].
  void rewindTo(int globalWordIndex);
}
