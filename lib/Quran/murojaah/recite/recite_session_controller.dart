import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:recite_quran/recite_quran.dart';

import 'asr_snapshot.dart';
import 'heard_word.dart';
import 'recite_session_engine.dart';

/// State dan keputusan satu sesi latihan murojaah — tanpa widget apa pun.
///
/// Pemindahan murni dari `_ReciteMurojaahPageState`: urutan pemanggilan matcher,
/// kapan snapshot diambil, dan kapan kursor tracker mundur harus tetap identik.
/// `heard_word.dart` tidak disentuh.
class ReciteSessionController extends ChangeNotifier {
  ReciteSessionController({required this.engine});

  final ReciteSessionEngine engine;

  StreamSubscription<WordMatchedEvent>? _wordSub;
  StreamSubscription<String>? _textSub;

  List<QuranVerse> _verses = const [];

  /// Offset kata global tiap ayat; panjang = jumlah ayat + 1.
  final List<int> _wordStarts = [];

  /// Kata global yang sudah diucapkan benar (hijau).
  final Set<int> _matched = {};

  /// Kata global yang salah / terlupa (merah).
  final Set<int> _missed = {};

  /// Transkrip ASR per ayat + bunyi tiap kata merah, terikat ke satu percobaan.
  final AsrSnapshot _asr = AsrSnapshot();

  /// Kata yang sedang dibuka sementara (peek hint) + jumlah peek.
  int? _peekWord;
  int _peekCount = 0;
  Timer? _peekTimer;

  /// Transkrip fonetis ASR terakhir (hipotesis kumulatif segmen aktif) —
  /// bahan `LcsOmissionDetector`.
  String _asrText = '';

  /// Panjang awalan [_asrRaw] yang sudah menjadi milik ayat-ayat sebelumnya.
  int _asrOffset = 0;

  /// Transkrip penuh segmen aktif, sebelum dipotong [_asrOffset].
  String _asrRaw = '';

  /// Awalan [_asrRaw] saat [_asrOffset] dihitung. Bila transkrip berikutnya
  /// tidak lagi berawalan sama, engine memulai segmen baru dan offset gugur.
  String _asrAnchor = '';

  int _activeVerse = 0;
  bool _sawEvent = false;
  bool _disposed = false;

  // ── State yang dibaca UI ────────────────────────────────────────────────

  List<QuranVerse> get verses => _verses;
  Set<int> get matched => _matched;
  Set<int> get missed => _missed;
  int get activeVerse => _activeVerse;
  int? get peekWord => _peekWord;
  int get peekCount => _peekCount;
  int get totalWords => engine.wordPhonemes.length;

  /// Semua kata sudah hijau.
  bool get isComplete => totalWords > 0 && _matched.length >= totalWords;

  /// Ayat aktif punya kata merah → tombol "Ulangi ayat ini" aktif.
  bool get activeVerseMissed {
    if (_wordStarts.length < 2) return false;
    final start = _wordStarts[_activeVerse];
    final end = _wordStarts[_activeVerse + 1];
    return _missed.any((id) => id >= start && id < end);
  }

  /// Akurasi bacaan: benar / (benar + salah). 100% bila belum ada percobaan.
  double get accuracy {
    final attempts = _matched.length + _missed.length;
    return attempts == 0 ? 1 : _matched.length / attempts;
  }

  /// Ayat aktif sudah punya percobaan (benar atau salah).
  bool get sawEvent => _sawEvent;

  /// Ayat ke-[verse] (0-based) sudah terbaca penuh: semua katanya hijau.
  ///
  /// Dipakai untuk mencatat progres per ayat — bukan per kata.
  bool isVerseComplete(int verse) {
    if (_wordStarts.length < 2) return false;
    if (verse < 0 || verse + 1 >= _wordStarts.length) return false;
    final start = _wordStarts[verse];
    final end = _wordStarts[verse + 1];
    if (end <= start) return false;
    for (var id = start; id < end; id++) {
      if (!_matched.contains(id)) return false;
    }
    return true;
  }

  /// Teks kata global [wordId] dari ayat pemiliknya.
  String wordText(int wordId) {
    if (wordId < 0 || _verses.isEmpty) return '';
    final verse = _verseOf(wordId);
    final words = _verses[verse].uthmaniWords;
    final local = wordId - _wordStarts[verse];
    return local >= 0 && local < words.length ? words[local] : '';
  }

  /// Bunyi ASR yang menempati slot kata merah [wordId], atau null bila kata
  /// itu memang tidak diucapkan. Lihat [heardForWord].
  String? heardOf(int wordId) {
    if (_asr.hasHeard(wordId)) return _asr.heardOf(wordId);
    final verse = _verseOf(wordId);
    final text = _asr.textOf(verse);
    if (text == null || text.trim().isEmpty) return null;
    return heardForWord(
      phonemesPerWord: engine.wordPhonemes.sublist(
        _wordStarts[verse],
        _wordStarts[verse + 1],
      ),
      wordIndex: wordId - _wordStarts[verse],
      emitted: text,
    );
  }

  // ── Pemasangan sumber data ──────────────────────────────────────────────

  /// Ambil ayat dari engine, hitung offset kata, dan pasang listener.
  ///
  /// Aman dipanggil berkali-kali; hanya bereaksi saat daftar ayat berubah.
  /// Mengembalikan `true` bila ayat baru saja diadopsi.
  bool adoptVerses() {
    final verses = engine.verses;
    if (verses.isEmpty || identical(verses, _verses)) return false;
    _verses = verses;
    _wordStarts
      ..clear()
      ..addAll(engine.wordAyahStarts);
    _wordSub ??= engine.wordEvents.listen(onWordEvent);
    _textSub ??= engine.transcript.listen(onTranscript);
    notifyListeners();
    return true;
  }

  /// Transkrip mentah [text] dari engine.
  void onTranscript(String text) {
    _setAsr(text);
    notifyListeners();
  }

  /// Satu event kata dari matcher.
  void onWordEvent(WordMatchedEvent event) {
    if (_disposed || _verses.isEmpty) return;
    final verse = _verseOf(event.wordId);

    if (event.isRed) {
      _onRed(event, verse);
      return;
    }

    // Matcher menormalkan biaya salah baca per panjang kata acuan, sehingga
    // satu fonem salah pada kata panjang tetap hijau. Periksa ulang hurufnya.
    if (_soundsWrong(event)) {
      // Bunyi pengganti sudah ada di slot kata ini, jadi jangan cari kata
      // yang dilewati: `LcsOmissionDetector` akan menuduh kata lain.
      _onRed(event, verse, detectOmission: false);
      return;
    }

    _sawEvent = true;
    _matched.add(event.wordId);
    _missed.remove(event.wordId);
    // Kata ini sekarang benar: bunyi lama tidak relevan lagi.
    _asr.forgetHeard([event.wordId]);
    if (_peekWord == event.wordId) _peekWord = null;
    if (verse != _activeVerse) _switchVerse(verse);
    notifyListeners();

    if (isComplete) unawaited(engine.stopListening());
  }

  /// Kata salah/terlupa: tandai merah, getarkan perangkat, dan cari kata yang
  /// dilewati lewat `LcsOmissionDetector` (Best-Drop LCS).
  void _onRed(WordMatchedEvent event, int verse, {bool detectOmission = true}) {
    unawaited(HapticFeedback.mediumImpact());
    // Ayat baru: potong dulu bunyi ayat sebelumnya, baru baca slot kata ini.
    if (verse != _activeVerse) _switchVerse(verse);
    final omitted = detectOmission ? _omittedWord(event.wordId, verse) : null;
    // Bunyi slot dicatat **sekarang**, dari transkrip yang sedang dinilai.
    _keepSnapshot(verse);
    final heard = _heardAt(
      event.wordId,
      _asrText.isEmpty ? (_asr.textOf(verse) ?? '') : _asrText,
    );
    _missed.add(event.wordId);
    _matched.remove(event.wordId);
    _asr.recordHeard(event.wordId, heard);
    if (omitted != null) _missed.add(omitted);
    notifyListeners();
  }

  // ── Intip kata ──────────────────────────────────────────────────────────

  /// Buka satu kata berikutnya selama 2 detik (peek hint).
  void peek() {
    final total = totalWords;
    if (total == 0) return;
    final from = _wordStarts.length > 1 ? _wordStarts[_activeVerse] : 0;
    var target = -1;
    for (var i = from; i < total; i++) {
      if (!_matched.contains(i) && !_missed.contains(i)) {
        target = i;
        break;
      }
    }
    if (target < 0) return;
    _peekTimer?.cancel();
    _peekWord = target;
    _peekCount++;
    notifyListeners();
    _peekTimer = Timer(const Duration(seconds: 2), () {
      if (_disposed) return;
      _peekWord = null;
      notifyListeners();
    });
  }

  // ── Ulangi / mulai ulang ────────────────────────────────────────────────

  /// Ulangi ayat aktif: buang tanda merah ayat ini dan kembalikan kursor
  /// pelacakan ke kata pertama ayat tersebut.
  ///
  /// Kata yang sudah hijau tetap terbuka: kursor mundur membuat tracker
  /// mengirim ulang event kata-kata itu, dan hasilnya sama.
  void retryCurrentVerse() {
    if (_wordStarts.length < 2) return;
    final start = _wordStarts[_activeVerse];
    final end = _wordStarts[_activeVerse + 1];
    engine.rewindTo(start);
    _missed.removeWhere((id) => id >= start && id < end);
    // Percobaan baru: transkrip & bunyi kata ayat ini dibuang supaya
    // "terdengar" tidak memakai bacaan lama.
    _asr.rewind(forgetWords: Iterable.generate(end - start, (i) => start + i));
    _resetAsr();
    notifyListeners();
    unawaited(_resumeListening());
  }

  /// Kembali ke ayat pertama.
  void resetAll() {
    _peekTimer?.cancel();
    engine.rewindTo(0);
    _activeVerse = 0;
    _matched.clear();
    _missed.clear();
    _asr.rewind(forgetWords: Iterable.generate(totalWords, (i) => i));
    _peekWord = null;
    _peekCount = 0;
    _resetAsr();
    notifyListeners();
    unawaited(_resumeListening());
  }

  /// Nyalakan lagi mikrofon bila sesi sebelumnya sudah berjalan tetapi berhenti
  /// (mis. semua kata hijau memicu `stopListening`).
  Future<void> _resumeListening() async {
    if (!_sawEvent) return;
    if (engine.status.value != ReciteMurojaahStatus.ready) return;
    await engine.startListening();
  }

  // ── Penilaian ───────────────────────────────────────────────────────────

  /// Kata yang dilaporkan hijau tetapi hurufnya berbeda dari acuan.
  bool _soundsWrong(WordMatchedEvent event) {
    if (event.wordId < 0 || event.wordId >= engine.wordPhonemes.length) {
      return false;
    }
    return isWrongReading(engine.wordPhonemes[event.wordId], event.cleanAsr);
  }

  /// Simpan transkrip terpanjang percobaan ini untuk [verse].
  void _keepSnapshot(int verse) => _asr.keep(verse, _asrText);

  /// Terima transkrip mentah [text] dari engine.
  ///
  /// Transkrip satu segmen bersifat kumulatif: memuat bunyi semua ayat yang
  /// sudah dibaca. Awalan milik ayat sebelumnya dipotong ([_asrOffset]).
  void _setAsr(String text) {
    if (_asrOffset > 0 && !_segmentHolds(text)) {
      // Engine mulai segmen baru: potongan lama tidak berlaku.
      _asrOffset = 0;
      _asrAnchor = '';
    }
    _asrRaw = text;
    final cut = _asrOffset > text.length ? text.length : _asrOffset;
    _asrText = cut == 0 ? text : text.substring(cut);
  }

  /// Apakah [text] masih segmen yang sama dengan saat offset dihitung?
  bool _segmentHolds(String text) {
    if (text.length < _asrOffset || _asrAnchor.isEmpty) return false;
    final from = _asrOffset - _asrAnchor.length;
    return text.startsWith(_asrAnchor, from);
  }

  /// Pindah ayat aktif: simpan transkrip ayat lama, lalu potong bagiannya.
  void _switchVerse(int verse) {
    _keepSnapshot(_activeVerse);
    _activeVerse = verse;
    _syncOffset(verse);
  }

  /// Buang transkrip berjalan (percobaan baru).
  void _resetAsr() {
    _asrRaw = '';
    _asrText = '';
    _asrOffset = 0;
  }

  /// Potong awalan transkrip yang sudah dipakai kata-kata **sebelum** ayat
  /// [verse].
  void _syncOffset(int verse) {
    if (_asrRaw.isEmpty) return;
    final before = verse > 0 && verse < _wordStarts.length
        ? _wordStarts[verse]
        : 0;
    if (before <= 0) {
      _asrOffset = 0;
    } else {
      _asrOffset = asrConsumed(
        phonemesPerWord: engine.wordPhonemes.sublist(0, before),
        emitted: _asrRaw,
      );
    }
    // Ekor potongan dipakai mengenali segmen yang sama pada transkrip berikut.
    _asrAnchor = _asrOffset <= 0
        ? ''
        : _asrRaw.substring(max(0, _asrOffset - 8), _asrOffset);
    _setAsr(_asrRaw);
  }

  /// Bunyi ASR yang menempati slot kata global [wordId] pada transkrip [text].
  String? _heardAt(int wordId, String text) {
    if (text.trim().isEmpty) return null;
    final verse = _verseOf(wordId);
    if (verse + 1 >= _wordStarts.length) return null;
    return heardForWord(
      phonemesPerWord: engine.wordPhonemes.sublist(
        _wordStarts[verse],
        _wordStarts[verse + 1],
      ),
      wordIndex: wordId - _wordStarts[verse],
      emitted: text,
    );
  }

  /// Indeks kata global yang paling mungkin dilewati, atau null.
  int? _omittedWord(int wordId, int verse) {
    final emitted = _asrText.trim();
    if (emitted.isEmpty || engine.wordPhonemes.isEmpty) return null;
    final start = _wordStarts[verse];
    final end = _wordStarts[verse + 1];
    final result = LcsOmissionDetector.detectOmission(
      phonemesPerWord: engine.wordPhonemes.sublist(start, end),
      emittedPhonemes: emitted,
    );
    if (!result.isOmissionDetected) return null;
    final index = result.omittedWordIndex;
    if (index == null) return null;
    final global = start + index;
    return global == wordId ? null : global;
  }

  /// Ayat pemilik kata global [wordId] (0-based).
  int _verseOf(int wordId) {
    var lo = 0;
    var hi = _verses.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_wordStarts[mid] <= wordId) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  @override
  void dispose() {
    _disposed = true;
    _peekTimer?.cancel();
    _peekTimer = null;
    _wordSub?.cancel();
    _wordSub = null;
    _textSub?.cancel();
    _textSub = null;
    super.dispose();
  }
}
