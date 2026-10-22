import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:recite_quran/recite_quran.dart';

import '../../data/quran_tokens.dart';
import '../../presentation/widgets/quran_status_bar.dart';
import '../../presentation/widgets/quran_theme_scope.dart';
import 'recite_murojaah_service.dart';
import 'widgets/recite_controls.dart';
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

  /// Teks yang terdengar (ASR) saat kata ditandai merah — bahan sheet koreksi.
  final Map<int, String> _heard = {};

  /// Kata yang sedang dibuka sementara (peek hint) + jumlah peek.
  int? _peekWord;
  int _peekCount = 0;
  Timer? _peekTimer;

  /// Transkrip fonetis ASR terakhir (hipotesis kumulatif segmen aktif) —
  /// bahan `LcsOmissionDetector`.
  String _asrText = '';

  int _activeVerse = 0;
  bool _sawEvent = false;

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
    _textSub ??= _service.transcript.listen((text) => _asrText = text);
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
      _onRed(event, verse);
      return;
    }

    if (!_sawEvent) {
      _sawEvent = true;
      _log('event pertama: wordId=${event.wordId}');
    }

    setState(() {
      _matched.add(event.wordId);
      _missed.remove(event.wordId);
      _heard.remove(event.wordId);
      if (_peekWord == event.wordId) _peekWord = null;
      if (verse != _activeVerse) _asrText = '';
      _activeVerse = verse;
    });
    if (_matched.length >= _service.wordPhonemes.length) {
      unawaited(_service.stopListening());
      _log('surah selesai: ${_matched.length} kata');
    }
  }

  /// Kata salah/terlupa: tandai merah, getarkan perangkat, dan cari kata yang
  /// dilewati lewat `LcsOmissionDetector` (Best-Drop LCS).
  void _onRed(WordMatchedEvent event, int verse) {
    unawaited(HapticFeedback.mediumImpact());
    final omitted = _omittedWord(event.wordId, verse);
    final heard = event.cleanAsr.trim();
    setState(() {
      _missed.add(event.wordId);
      _matched.remove(event.wordId);
      if (heard.isNotEmpty) _heard[event.wordId] = heard;
      if (omitted != null) _missed.add(omitted);
      _activeVerse = verse;
    });
    _log('merah wordId=${event.wordId} ayat=${verse + 1}');
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
    final dark = QuranThemeScope.darkOf(context);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: QuranTokens.surface(dark),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _CorrectionSheet(
          expected: _wordText(wordId),
          heard: _heard[wordId],
          dark: dark,
        ),
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

  /// Ulangi ayat aktif: buang tanda merah ayat ini.
  void _retryCurrent() {
    final start = _wordStarts[_activeVerse];
    final end = _wordStarts[_activeVerse + 1];
    setState(() {
      _missed.removeWhere((id) => id >= start && id < end);
      _matched.removeWhere((id) => id >= start && id < end);
      _heard.removeWhere((id, _) => id >= start && id < end);
      _asrText = '';
    });
  }

  /// Kembali ke ayat pertama.
  void _resetAll() {
    _peekTimer?.cancel();
    setState(() {
      _activeVerse = 0;
      _matched.clear();
      _missed.clear();
      _heard.clear();
      _peekWord = null;
      _peekCount = 0;
      _asrText = '';
    });
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

/// Sheet koreksi untuk kata merah: kata yang diharapkan vs yang terdengar.
class _CorrectionSheet extends StatelessWidget {
  const _CorrectionSheet({
    required this.expected,
    required this.heard,
    required this.dark,
  });

  final String expected;
  final String? heard;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final green = QuranTokens.successColor(dark);
    final red = Colors.red.shade400;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Koreksi kata',
              textAlign: TextAlign.center,
              style: QuranTokens.poppins(
                TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: QuranTokens.secondaryColor(dark),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SheetSide(
                    label: 'Seharusnya',
                    text: expected,
                    color: green,
                    size: 30,
                    dark: dark,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: Icon(
                    Icons.arrow_back,
                    size: 18,
                    color: QuranTokens.secondaryColor(dark).withValues(alpha: 0.6),
                  ),
                ),
                Expanded(
                  child: _SheetSide(
                    label: 'Terdengar',
                    text: heard == null || heard!.isEmpty ? 'tidak terdengar' : heard!,
                    color: red,
                    size: heard == null || heard!.isEmpty ? 14 : 22,
                    dark: dark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSide extends StatelessWidget {
  const _SheetSide({
    required this.label,
    required this.text,
    required this.color,
    required this.size,
    required this.dark,
  });

  final String label;
  final String text;
  final Color color;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: QuranTokens.poppins(
            TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: QuranTokens.secondaryColor(dark),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: QuranTokens.amiri(
            TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }
}
