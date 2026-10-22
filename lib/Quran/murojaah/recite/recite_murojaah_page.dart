import 'dart:async';

import 'package:flutter/material.dart';
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

  List<QuranVerse> _verses = const [];
  /// Offset kata global tiap ayat; panjang = jumlah ayat + 1.
  final List<int> _wordStarts = [];

  /// Kata ayat aktif yang sudah cocok (hijau/kuning).
  final Set<int> _matched = {};
  int _revealed = 0;
  bool _retrying = false;
  int? _lastMatchedWord;

  @override
  void initState() {
    super.initState();
    _service = ReciteMurojaahService(surahNumber: widget.surahNumber);
    _service.status.addListener(_onStatus);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _service.status.removeListener(_onStatus);
    _wordSub?.cancel();
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
    setState(() {});
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
    if (!mounted || _revealed >= _verses.length) return;
    // Hanya ayat aktif (pertama yang belum terbuka) yang dinilai.
    if (_verseOf(event.wordId) != _revealed) return;

    if (event.isRed) {
      if (!_retrying || _matched.isNotEmpty) {
        setState(() {
          _retrying = true;
          _matched.clear();
        });
      }
      return;
    }

    _matched.add(event.wordId);
    final needed = _wordStarts.length > _revealed + 1
        ? _wordStarts[_revealed + 1] - _wordStarts[_revealed]
        : 0;
    final complete = needed > 0 && _matched.length >= needed;
    setState(() {
      _lastMatchedWord = event.wordId;
      _retrying = false;
      if (complete) {
        _revealed++;
        _matched.clear();
        _lastMatchedWord = null;
      }
    });
    if (_revealed >= _verses.length) unawaited(_service.stopListening());
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

  /// Ulangi ayat aktif (hapus progres kata ayat ini).
  void _retryCurrent() {
    setState(() {
      _retrying = false;
      _matched.clear();
      _lastMatchedWord = null;
    });
  }

  /// Kembali ke ayat pertama.
  void _resetAll() {
    setState(() {
      _revealed = 0;
      _retrying = false;
      _matched.clear();
      _lastMatchedWord = null;
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
              _Header(dark: dark, title: _title),
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
    final total = _verses.length;
    final done = _revealed >= total;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : _revealed / total,
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
              '${arabicIndic(_revealed)} / ${arabicIndic(total)}',
              textDirection: TextDirection.rtl,
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
            revealedCount: _revealed,
            lastMatchedWord: _lastMatchedWord,
            retryVerseIndex: _retrying ? _revealed : null,
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
            final done = _verses.isNotEmpty && _revealed >= _verses.length;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_retrying)
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
                        onTap: _revealed == 0 && !_retrying ? null : _resetAll,
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
                        urgency: _retrying ? Colors.red.shade400 : null,
                        onTap: _retrying || _matched.isNotEmpty
                            ? _retryCurrent
                            : null,
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

/// Header ringkas: kembali, nama surah, toggle tema.
class _Header extends StatelessWidget {
  const _Header({required this.dark, required this.title});

  final bool dark;
  final String title;

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
