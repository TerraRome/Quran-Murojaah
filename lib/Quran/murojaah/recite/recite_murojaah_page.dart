import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:recite_quran/recite_quran.dart';

import '../../data/quran_tokens.dart';
import '../../presentation/widgets/quran_status_bar.dart';
import '../../presentation/widgets/quran_theme_scope.dart';
import 'asr_snapshot.dart';
import 'heard_word.dart';
import 'recite_murojaah_service.dart';
import 'widgets/recite_controls.dart';
import 'widgets/recite_correction_sheet.dart';
import 'widgets/recite_mushaf.dart';

/// Halaman Murojaah baru: mushaf tersembunyi yang terbuka ayat demi ayat
/// berdasarkan hasil pelacakan `recite_quran`.
///
/// Halaman memiliki lifecycle service (create → initialize → dispose).
class ReciteMurojaahPage extends StatefulWidget {
  const ReciteMurojaahPage({super.key, required this.surahNumber});

  final int surahNumber;

  @override
  State<ReciteMurojaahPage> createState() => _ReciteMurojaahPageState();
}

class _ReciteMurojaahPageState extends State<ReciteMurojaahPage> {
  late final ReciteMurojaahService _service;
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
  ///
  /// Transkrip kumulatif satu segmen memuat semua ayat yang sudah dibaca. Tanpa
  /// offset ini, kata pertama ayat baru bisa mendapat slot dari bunyi ayat lama
  /// (sheet koreksi menampilkan bacaan ayat 1 untuk kata ayat 7).
  int _asrOffset = 0;

  /// Transkrip penuh segmen aktif, sebelum dipotong [_asrOffset].
  String _asrRaw = '';

  /// Awalan [_asrRaw] saat [_asrOffset] dihitung. Bila transkrip berikutnya
  /// tidak lagi berawalan sama, engine memulai segmen baru dan offset gugur.
  String _asrAnchor = '';

  int _activeVerse = 0;
  bool _sawEvent = false;

  /// TEMP-DIAG: nomor percobaan, naik setiap Ulangi/Reset.
  int _diagAttempt = 0;

  /// TEMP-DIAG: transkrip terakhir yang sudah dilaporkan (hindari duplikat).
  String _diagLastText = '';

  @override
  void initState() {
    super.initState();
    _service = ReciteMurojaahService(surahNumber: widget.surahNumber);
    _service.status.addListener(_onStatus);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _peekTimer?.cancel();
    _service.status.removeListener(_onStatus);
    _wordSub?.cancel();
    _textSub?.cancel();
    unawaited(_service.dispose());
    super.dispose();
  }

  Future<void> _initialize() async {
    await _service.initialize();
    if (!mounted) return;
    _adoptVerses();
  }

  void _onStatus() {
    if (!mounted) return;
    if (_service.status.value == ReciteMurojaahStatus.ready) _adoptVerses();
    setState(() {});
  }

  /// Ambil ayat dari service, hitung offset kata, dan pasang listener kata.
  void _adoptVerses() {
    final verses = _service.verses;
    if (verses.isEmpty || identical(verses, _verses)) return;
    _verses = verses;
    _wordStarts
      ..clear()
      ..addAll(_service.wordAyahStarts);
    _wordSub ??= _service.wordEvents.listen(_onWord);
    _textSub ??= _service.transcript.listen((text) {
      _diagTranscript(text);
      _setAsr(text);
    });
    setState(() {});
  }

  /// Ayat aktif punya kata merah → tombol "Ulangi" aktif.
  bool get _activeVerseMissed {
    if (_wordStarts.length < 2) return false;
    final start = _wordStarts[_activeVerse];
    final end = _wordStarts[_activeVerse + 1];
    return _missed.any((id) => id >= start && id < end);
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

  void _onWord(WordMatchedEvent event) {
    if (!mounted || _verses.isEmpty) return;
    final verse = _verseOf(event.wordId);

    if (event.isRed) {
      _diagEvent(event, verse, 'RED');
      _onRed(event, verse);
      return;
    }

    // Matcher menormalkan biaya salah baca per panjang kata acuan, sehingga
    // satu fonem salah pada kata panjang tetap hijau. Periksa ulang hurufnya.
    if (_soundsWrong(event)) {
      _diagEvent(event, verse, 'GREEN→RED');
      // Bunyi pengganti sudah ada di slot kata ini, jadi jangan cari kata
      // yang dilewati: `LcsOmissionDetector` akan menuduh kata lain.
      _onRed(event, verse, detectOmission: false);
      return;
    }
    _diagEvent(event, verse, 'GREEN');

    if (!_sawEvent) {
      _sawEvent = true;
      _log('event pertama: wordId=${event.wordId}');
    }

    setState(() {
      _matched.add(event.wordId);
      _missed.remove(event.wordId);
      // Kata ini sekarang benar: bunyi lama tidak relevan lagi.
      _asr.forgetHeard([event.wordId]);
      if (_peekWord == event.wordId) _peekWord = null;
      if (verse != _activeVerse) _switchVerse(verse);
    });
    if (_matched.length >= _service.wordPhonemes.length) {
      unawaited(_service.stopListening());
      _log('surah selesai: ${_matched.length} kata');
    }
  }

  /// Kata yang dilaporkan hijau tetapi hurufnya berbeda dari acuan.
  ///
  /// Memakai `cleanAsr` event — potongan transkrip yang benar-benar dipakai
  /// matcher untuk kata ini, jadi tidak perlu menyusun ulang slot dari
  /// transkrip live.
  bool _soundsWrong(WordMatchedEvent event) {
    if (event.wordId < 0 || event.wordId >= _service.wordPhonemes.length) {
      return false;
    }
    return isWrongReading(
      _service.wordPhonemes[event.wordId],
      event.cleanAsr,
    );
  }

  /// Simpan transkrip terpanjang percobaan ini untuk [verse] — dipakai sheet
  /// koreksi. Lihat [AsrSnapshot.keep].
  void _keepSnapshot(int verse) => _asr.keep(verse, _asrText);

  /// Terima transkrip mentah [text] dari engine.
  ///
  /// Transkrip satu segmen bersifat kumulatif: memuat bunyi semua ayat yang
  /// sudah dibaca. Awalan yang sudah menjadi milik ayat sebelumnya dipotong
  /// ([_asrOffset]) supaya slot kata ayat aktif tidak mengambilnya.
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
  ///
  /// Dicek dari ekor potongan (dekat titik potong), bukan seluruh awalan:
  /// hipotesis parsial boleh merevisi bagian jauh sebelumnya.
  bool _segmentHolds(String text) {
    if (text.length < _asrOffset || _asrAnchor.isEmpty) return false;
    final from = _asrOffset - _asrAnchor.length;
    return text.startsWith(_asrAnchor, from);
  }

  /// Pindah ayat aktif: simpan transkrip ayat lama, lalu potong bagiannya dari
  /// transkrip berjalan supaya tidak terbawa ke ayat baru.
  void _switchVerse(int verse) {
    _keepSnapshot(_activeVerse);
    _activeVerse = verse;
    _syncOffset(verse);
  }

  /// Buang transkrip berjalan (percobaan baru). Offset ikut nol karena
  /// transkrip berikutnya dimulai dari segmen baru.
  void _resetAsr() {
    _asrRaw = '';
    _asrText = '';
    _asrOffset = 0;
  }

  /// Potong awalan transkrip yang sudah dipakai kata-kata **sebelum** ayat
  /// [verse].
  ///
  /// Dihitung dari seluruh kata sebelum ayat ini, bukan hanya ayat aktif
  /// sebelumnya: event merah bisa melompat beberapa ayat sekaligus (ayat yang
  /// dilewati) sehingga ayat-ayat di antaranya tidak pernah menjadi aktif.
  void _syncOffset(int verse) {
    if (_asrRaw.isEmpty) return;
    final before = verse > 0 && verse < _wordStarts.length
        ? _wordStarts[verse]
        : 0;
    if (before <= 0) {
      _asrOffset = 0;
    } else {
      _asrOffset = asrConsumed(
        phonemesPerWord: _service.wordPhonemes.sublist(0, before),
        emitted: _asrRaw,
      );
    }
    // Ekor potongan dipakai mengenali segmen yang sama pada transkrip berikut.
    _asrAnchor = _asrOffset <= 0
        ? ''
        : _asrRaw.substring(max(0, _asrOffset - 8), _asrOffset);
    _setAsr(_asrRaw);
  }

  /// Kata salah/terlupa: tandai merah, getarkan perangkat, dan cari kata yang
  /// dilewati lewat `LcsOmissionDetector` (Best-Drop LCS).
  ///
  /// `WordMatchedEvent.cleanAsr` selalu kosong untuk event merah
  /// (`DictationSequencer._commitRed`), jadi teks "terdengar" tidak diambil dari
  /// event melainkan direkonstruksi dari transkrip ayat (`heardForWord`).
  void _onRed(
    WordMatchedEvent event,
    int verse, {
    bool detectOmission = true,
  }) {
    unawaited(HapticFeedback.mediumImpact());
    // Ayat baru: potong dulu bunyi ayat sebelumnya, baru baca slot kata ini.
    if (verse != _activeVerse) _switchVerse(verse);
    final omitted = detectOmission ? _omittedWord(event.wordId, verse) : null;
    // Bunyi slot dicatat **sekarang**, dari transkrip yang sedang dinilai.
    // Menghitungnya lagi saat sheet dibuka akan memakai transkrip yang sudah
    // bertambah (kata berikutnya) atau sudah direset percobaan lain.
    _keepSnapshot(verse);
    final heard = _heardAt(
      event.wordId,
      _asrText.isEmpty ? (_asr.textOf(verse) ?? '') : _asrText,
    );
    setState(() {
      _missed.add(event.wordId);
      _matched.remove(event.wordId);
      _asr.recordHeard(event.wordId, heard);
      if (omitted != null) _missed.add(omitted);
    });
    _log('merah wordId=${event.wordId} ayat=${verse + 1}');
  }

  /// Bunyi ASR yang menempati slot kata global [wordId] pada transkrip [text].
  String? _heardAt(int wordId, String text) {
    if (text.trim().isEmpty) return null;
    final verse = _verseOf(wordId);
    if (verse + 1 >= _wordStarts.length) return null;
    return heardForWord(
      phonemesPerWord: _service.wordPhonemes.sublist(
        _wordStarts[verse],
        _wordStarts[verse + 1],
      ),
      wordIndex: wordId - _wordStarts[verse],
      emitted: text,
    );
  }

  /// Indeks kata global yang paling mungkin dilewati, atau null.
  ///
  /// Memakai transkrip fonetis live sebagai `emittedPhonemes`; bila belum ada
  /// transkrip, deteksi dilewati (tidak ada bukti).
  int? _omittedWord(int wordId, int verse) {
    final emitted = _asrText.trim();
    if (emitted.isEmpty || _service.wordPhonemes.isEmpty) return null;
    final start = _wordStarts[verse];
    final end = _wordStarts[verse + 1];
    final result = LcsOmissionDetector.detectOmission(
      phonemesPerWord: _service.wordPhonemes.sublist(start, end),
      emittedPhonemes: emitted,
    );
    if (!result.isOmissionDetected) return null;
    final index = result.omittedWordIndex;
    if (index == null) return null;
    final global = start + index;
    return global == wordId ? null : global;
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[Murojaah] $message');
  }

  /// TEMP-DIAG: transkrip berubah → hitung ulang keputusan tiap kata ayat aktif
  /// terhadap transkrip terbaru. Membuktikan apakah merah/hijau berubah saat
  /// hasil partial menjadi final.
  void _diagTranscript(String text) {
    if (!kDebugMode) return;
    if (text.isEmpty || _wordStarts.length < 2) return;
    if (text == _diagLastText) return;
    _diagLastText = text;
    final verse = _activeVerse;
    final start = _wordStarts[verse];
    final end = _wordStarts[verse + 1];
    final words = _service.wordPhonemes.sublist(start, end);
    final buf = StringBuffer(
      '[DIAG][TEXT] coba=$_diagAttempt ayah=${verse + 1} len=${text.length}',
    );
    for (var i = 0; i < words.length; i++) {
      final heard = heardForWord(
        phonemesPerWord: words,
        wordIndex: i,
        emitted: text,
      );
      final wrong = isWrongReading(words[i], heard);
      buf.write(' | w$i wrong=$wrong slot="${heard ?? ''}"');
    }
    debugPrint(buf.toString());
    debugPrint('[DIAG][TEXT] raw="$text"');
  }

  /// TEMP-DIAG: satu baris per percobaan kata — acuan, transkrip mentah,
  /// status matcher, `cleanAsr`, hasil `isWrongReading`, dan keputusan akhir.
  void _diagEvent(WordMatchedEvent event, int verse, String verdict) {
    if (!kDebugMode) return;
    final ref = _service.phonemesOf(event.wordId);
    final start = _wordStarts[verse];
    final local = event.wordId - start;
    final heard = heardForWord(
      phonemesPerWord: _service.wordPhonemes.sublist(
        start,
        _wordStarts[verse + 1],
      ),
      wordIndex: local,
      emitted: _asrText,
    );
    final wrong = isWrongReading(ref, event.cleanAsr);
    debugPrint(
      '[DIAG][WORD] coba=$_diagAttempt ayah=${verse + 1} '
      'w=$local/${_wordStarts[verse + 1] - start} '
      'text="${_wordText(event.wordId)}" ref="$ref" '
      'status=${event.isRed ? 'RED' : 'GREEN'} '
      'score=${event.score.toStringAsFixed(3)} '
      'cleanAsr="${event.cleanAsr}" heard="${heard ?? ''}" '
      'isWrong=$wrong verdict=$verdict',
    );
    debugPrint(
      '[DIAG][WORD] asr="$_asrText" slot="${heard ?? ''}" '
      'slotDisplay="${heard == null ? '' : displayHeard(heard)}"',
    );
  }
  /// Teks kata global [wordId] dari ayat pemiliknya.
  ///
  /// `wordId` mengikuti kata fonetis; jumlah kata fonetis = jumlah kata
  /// `aya_text` per ayat, jadi offset lokal bisa dipakai langsung.
  String _wordText(int wordId) {
    final verse = _verseOf(wordId);
    final words = _verses[verse].uthmaniWords;
    final local = wordId - _wordStarts[verse];
    return local >= 0 && local < words.length ? words[local] : '';
  }

  /// Bunyi ASR yang menempati slot kata merah [wordId], atau null bila kata
  /// itu memang tidak diucapkan. Lihat [heardForWord].
  ///
  /// Nilai yang dicatat saat kata dinilai merah selalu dipakai lebih dulu;
  /// hitung ulang hanya cadangan untuk kata yang ditandai tanpa event.
  String? _heardOf(int wordId) {
    if (_asr.hasHeard(wordId)) return _asr.heardOf(wordId);
    final verse = _verseOf(wordId);
    final text = _asr.textOf(verse);
    if (text == null || text.trim().isEmpty) return null;
    return heardForWord(
      phonemesPerWord: _service.wordPhonemes.sublist(
        _wordStarts[verse],
        _wordStarts[verse + 1],
      ),
      wordIndex: wordId - _wordStarts[verse],
      emitted: text,
    );
  }

  /// Akurasi bacaan: benar / (benar + salah). 100% bila belum ada percobaan.
  double get _accuracy {
    final attempts = _matched.length + _missed.length;
    return attempts == 0 ? 1 : _matched.length / attempts;
  }

  /// Buka satu kata berikutnya selama 2 detik (peek hint).
  void _peek() {
    final total = _service.wordPhonemes.length;
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
    setState(() {
      _peekWord = target;
      _peekCount++;
    });
    _peekTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _peekWord = null);
    });
  }

  /// Sheet koreksi: kata yang diharapkan vs yang terdengar.
  void _showCorrection(int wordId) {
    unawaited(
      showReciteCorrectionSheet(
        context,
        expected: _wordText(wordId),
        heard: _heardOf(wordId),
        dark: QuranThemeScope.darkOf(context),
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (_service.status.value == ReciteMurojaahStatus.listening) {
      await _service.stopListening();
      return;
    }
    if (_service.status.value == ReciteMurojaahStatus.error) {
      await _initialize();
      return;
    }
    await _service.startListening();
  }

  /// Ulangi ayat aktif: buang tanda merah ayat ini dan kembalikan kursor
  /// pelacakan ke kata pertama ayat tersebut.
  ///
  /// Kata yang sudah hijau tetap terbuka (aturan §19): kursor mundur membuat
  /// tracker mengirim ulang event kata-kata itu, dan hasilnya sama.
  void _retryCurrent() {
    if (_wordStarts.length < 2) return;
    final start = _wordStarts[_activeVerse];
    final end = _wordStarts[_activeVerse + 1];
    _service.rewindTo(start);
    _diagAttempt++;
    _log('DIAG coba=$_diagAttempt mulai ulang ayat ${_activeVerse + 1}');
    setState(() {
      _missed.removeWhere((id) => id >= start && id < end);
      // Percobaan baru: transkrip & bunyi kata ayat ini dibuang supaya
      // "terdengar" tidak memakai bacaan lama.
      _asr.rewind(forgetWords: Iterable.generate(end - start, (i) => start + i));
      _resetAsr();
    });
    unawaited(_resumeListening());
  }

  /// Kembali ke ayat pertama.
  void _resetAll() {
    _peekTimer?.cancel();
    _service.rewindTo(0);
    _diagAttempt++;
    setState(() {
      _activeVerse = 0;
      _matched.clear();
      _missed.clear();
      _asr.rewind(forgetWords: Iterable.generate(_service.wordPhonemes.length, (i) => i));
      _peekWord = null;
      _peekCount = 0;
      _resetAsr();
    });
    unawaited(_resumeListening());
  }

  /// Nyalakan lagi mikrofon bila sesi sebelumnya sudah berjalan tetapi berhenti
  /// (mis. semua kata hijau memicu `stopListening`). Tanpa ini tombol Ulangi /
  /// Reset tampak mati: kursor sudah mundur, tapi tidak ada audio masuk.
  Future<void> _resumeListening() async {
    if (!_sawEvent) return;
    if (_service.status.value != ReciteMurojaahStatus.ready) return;
    await _service.startListening();
  }

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return QuranStatusBar(
      dark: dark,
      child: Scaffold(
        backgroundColor: QuranTokens.background(dark),
        body: SafeArea(
          child: Column(
            children: [
              _Header(dark: dark, title: _title, onPeek: _verses.isEmpty ? null : _peek),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _verses.isEmpty ? _placeholder(dark) : _mushaf(dark),
                ),
              ),
              _bottom(dark),
            ],
          ),
        ),
      ),
    );
  }

  String get _title => _verses.isEmpty
      ? 'Murojaah'
      : _verses.first.surahNameEn.isNotEmpty
          ? _verses.first.surahNameEn
          : _verses.first.surahName;

  Widget _placeholder(bool dark) {
    return ValueListenableBuilder<ReciteMurojaahStatus>(
      valueListenable: _service.status,
      builder: (context, status, _) {
        final loading = status != ReciteMurojaahStatus.error;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ReciteStatusChip(
                  status: status,
                  message: _service.errorMessage.value,
                  dark: dark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mushaf(bool dark) {
    final totalWords = _service.wordPhonemes.length;
    final done = totalWords > 0 && _matched.length >= totalWords;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalWords == 0 ? 0 : _matched.length / totalWords,
                  minHeight: 3,
                  backgroundColor: QuranTokens.divider(dark),
                  valueColor: AlwaysStoppedAnimation(
                    QuranTokens.brandColor(dark),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(_accuracy * 100).round()}%',
              textDirection: TextDirection.ltr,
              style: QuranTokens.poppins(
                TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: QuranTokens.successColor(dark),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Angka Latin: digit Arab-Indik + "/" membentuk satu run RTL
            // sehingga urutan terbaca terbalik walau paragraf LTR.
            Text(
              _peekCount == 0
                  ? '${_matched.length} / $totalWords'
                  : '${_matched.length} / $totalWords · $_peekCount lihat',
              textDirection: TextDirection.ltr,
              style: QuranTokens.poppins(
                TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: QuranTokens.secondaryColor(dark),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ReciteMushaf(
            verses: _verses,
            matched: _matched,
            missed: _missed,
            activeVerse: _activeVerse,
            peekWord: _peekWord,
            onWordTap: (id) {
              if (_missed.contains(id)) _showCorrection(id);
            },
          ),
        ),
        if (done) _completed(dark),
      ],
    );
  }

  Widget _completed(bool dark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 18, color: QuranTokens.brandColor(dark)),
          const SizedBox(width: 8),
          Text(
            'Surah selesai dibaca',
            style: QuranTokens.poppins(
              TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: QuranTokens.inkColor(dark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottom(bool dark) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: ValueListenableBuilder<ReciteMurojaahStatus>(
          valueListenable: _service.status,
          builder: (context, status, _) {
            final listening = status == ReciteMurojaahStatus.listening;
            final busy = status == ReciteMurojaahStatus.preparing ||
                status == ReciteMurojaahStatus.downloadingModel;
            final done = _service.wordPhonemes.isNotEmpty &&
                _matched.length >= _service.wordPhonemes.length;
            final retrying = _activeVerseMissed;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (retrying)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Ulangi ayat ini',
                      style: QuranTokens.poppins(
                        TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ReciteStatusChip(
                      status: status,
                      message: _service.errorMessage.value,
                      dark: dark,
                    ),
                  ),
                if (status == ReciteMurojaahStatus.downloadingModel)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ReciteDownloadBar(
                      progress: _service.downloadProgress,
                      dark: dark,
                    ),
                  ),
                if (done)
                  FilledButton.icon(
                    onPressed: _resetAll,
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text('Ulangi dari awal'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: QuranTokens.brandColor(dark),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ReciteIconAction(
                        icon: Icons.restart_alt,
                        label: 'Reset',
                        dark: dark,
                        onTap: _matched.isEmpty && _missed.isEmpty
                            ? null
                            : _resetAll,
                      ),
                      const SizedBox(width: 28),
                      ReciteMicButton(
                        listening: listening,
                        enabled: !busy,
                        dark: dark,
                        onTap: _toggleListening,
                      ),
                      const SizedBox(width: 28),
                      ReciteIconAction(
                        icon: Icons.refresh,
                        label: 'Ulangi',
                        dark: dark,
                        urgency: retrying ? Colors.red.shade400 : null,
                        onTap: retrying ? _retryCurrent : null,
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Header ringkas: kembali, nama surah, peek hint, toggle tema.
class _Header extends StatelessWidget {
  const _Header({required this.dark, required this.title, this.onPeek});

  final bool dark;
  final String title;
  final VoidCallback? onPeek;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: QuranTokens.inkColor(dark),
            tooltip: 'Kembali',
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: QuranTokens.poppins(QuranTokens.tsAppTitle).copyWith(
                color: QuranTokens.brandColor(dark),
              ),
            ),
          ),
          IconButton(
            onPressed: onPeek,
            icon: const Icon(Icons.visibility_outlined, size: 22),
            color: QuranTokens.inkColor(dark),
            tooltip: 'Lihat satu kata',
          ),
          IconButton(
            onPressed: () => QuranThemeScope.toggleDark(context),
            icon: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 24,
            ),
            color: QuranTokens.inkColor(dark),
            tooltip: 'Ganti tema',
          ),
        ],
      ),
    );
  }
}
