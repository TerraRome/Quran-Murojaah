import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/quran_controller.dart';
import '../../data/datasources/audio_local_datasource.dart';
import '../../data/datasources/equran_remote_datasource.dart';
import '../../data/quran_tokens.dart';
import '../../domain/entities/qari.dart';
import '../../domain/entities/surah.dart';
import '../../domain/failures/quran_failure.dart';
import '../../murojaah/progress/activity_entry.dart';
import '../../murojaah/progress/progress_controller.dart';
import '../../murojaah/progress/reading_dwell.dart';
import '../../murojaah/progress/reading_log_recorder.dart';
import '../../murottal/application/download_controller.dart';
import '../../murottal/application/murottal_controller.dart';
import '../../murottal/application/qari_store.dart';
import '../../murottal/presentation/widgets/download_progress_dialog.dart';
import '../../murottal/presentation/widgets/mini_player.dart';
import '../../tafsir/application/tafsir_controller.dart';
import '../../tafsir/presentation/widgets/tafsir_bottom_sheet.dart';
import '../widgets/quran_status_bar.dart';
import '../widgets/quran_theme_scope.dart';
import '../widgets/quran_top_bar.dart';
import '../widgets/surah_header_card.dart';
import '../widgets/verse_view.dart';

/// Halaman detail satu surah (Figma "Surah Details"): header gradient,
/// daftar ayat, navigasi surah sebelumnya/sesudahnya.
class SurahDetailPage extends StatefulWidget {
  const SurahDetailPage({
    super.key,
    required this.surahNumber,
    required this.controller,
    this.readingProgress,
  });

  final int surahNumber;
  final QuranController controller;

  /// Log aktivitas untuk mencatat "ayat dibaca". Null = tidak mencatat
  /// (dipakai pratinjau/test lama).
  final MurojaahProgressController? readingProgress;

  @override
  State<SurahDetailPage> createState() => _SurahDetailPageState();
}

class _SurahDetailPageState extends State<SurahDetailPage>
    with WidgetsBindingObserver {
  Surah? _surah;
  bool _loading = true;
  QuranFailure? _error;

  late final ReadingLogRecorder _readingRecorder;
  late final EquranRemoteDataSource _remoteDatasource;
  late final AudioLocalDataSource _localDataSource;
  late final TafsirController _tafsirController;
  late final MurottalController _murottalController;
  late final DownloadController _downloadController;
  late final ScrollController _scrollController;

  // GlobalKey per ayat — index = numberInSurah - 1
  final List<GlobalKey> _verseKeys = [];

  // Nomor ayat terakhir yang di-scroll ke — hindari scroll berulang untuk ayat sama
  int _lastScrolledAyat = 0;

  // Qari aktif — dibutuhkan untuk cek file lokal & download
  Qari _activeQari = Qari.defaultQari;

  @override
  void initState() {
    super.initState();
    _remoteDatasource = EquranRemoteDataSourceImpl();
    _localDataSource = AudioLocalDataSourceImpl();
    _tafsirController = TafsirController(datasource: _remoteDatasource);
    _murottalController = MurottalController(
      datasource: _remoteDatasource,
      localDataSource: _localDataSource,
      qariStore: QariStore.defaults(),
    );
    _downloadController = DownloadController(localDataSource: _localDataSource);
    _scrollController = ScrollController();
    _readingRecorder = ReadingLogRecorder(
      progress: widget.readingProgress,
      type: ActivityType.quranRead,
    );
    WidgetsBinding.instance.addObserver(this);
    _murottalController.addListener(_onMurottalStateChanged);
    _initQariFromPrefs();
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _readingRecorder.handleLifecycle(state);
  }

  /// Auto-scroll ke ayat aktif — baik mode full-surah maupun per-ayat.
  void _onMurottalStateChanged() {
    final state = _murottalController.value;
    if (state is! MurottalPlaying) return;
    if (state.surahNumber != widget.surahNumber) return;
    final ayat = state.currentAyat;
    if (ayat == 0 || ayat == _lastScrolledAyat) return;
    final keyIndex = ayat - 1;
    if (keyIndex < 0 || keyIndex >= _verseKeys.length) return;
    final ctx = _verseKeys[keyIndex].currentContext;
    if (ctx == null) return;
    _lastScrolledAyat = ayat;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.15,
    );
  }

  /// Update qari controller setelah SharedPreferences siap,
  /// lalu cek apakah file sudah ada lokal untuk qari ini.
  Future<void> _initQariFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final store = QariStore(prefs);
    _murottalController.updateQariStore(store);
    _activeQari = store.getSelectedQari();
    await _downloadController.checkIfDownloaded(
      _activeQari.id,
      widget.surahNumber,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readingRecorder
      ..flush()
      ..dispose();
    _murottalController.removeListener(_onMurottalStateChanged);
    _tafsirController.dispose();
    _murottalController.dispose();
    _downloadController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (widget.controller.surahs.isEmpty) {
      await widget.controller.load();
    }
    final surah = widget.controller.surahs
        .where((s) => s.number == widget.surahNumber)
        .firstOrNull;
    setState(() {
      _surah = surah;
      _loading = false;
      _error = surah == null
          ? const QuranAssetLoadFailure('Surah tidak ditemukan')
          : null;
    });
    if (surah != null) {
      // Siapkan GlobalKey per ayat untuk auto-scroll
      if (_verseKeys.length != surah.totalVerses) {
        _verseKeys
          ..clear()
          ..addAll(List.generate(surah.totalVerses, (_) => GlobalKey()));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.setLastRead(surah.number, 1);
      });
    }
  }

  /// Tandai semua ayat yang sedang tampil sebagai sudah dibaca.
  void _markVisibleRead() {
    _readingRecorder.markVisibleAsRead();
    _readingRecorder.flush();
  }

  void _openTafsir(int ayatNumber) async {
    final surah = _surah;
    if (surah == null) return;
    await _tafsirController.open(surah.number, ayatNumber);
    if (!mounted) return;
    await TafsirBottomSheet.show(
      context: context,
      controller: _tafsirController,
      verses: surah.verses,
      surahNumber: surah.number,
      totalAyat: surah.totalVerses,
      readingProgress: widget.readingProgress,
    );
  }

  void _onPlayAyat(int ayatNumber) {
    final surah = _surah;
    if (surah == null) return;
    if (_murottalController.isPlayingAyat(surah.number, ayatNumber)) {
      _murottalController.stop();
      return;
    }
    _murottalController.playAyat(
      surahNumber: surah.number,
      surahName: surah.transliteration,
      ayatNumber: ayatNumber,
      totalAyat: surah.totalVerses,
    );
  }

  /// Tombol aksi tunggal di header card.
  /// - File tersimpan + idle/paused → play/resume full surah
  /// - File tersimpan + playing     → pause
  /// - File belum ada / error       → download
  /// - Sedang download              → batalkan
  void _onHeaderActionTap() {
    final dlState = _downloadController.value;
    if (dlState is DownloadCompleted) {
      _onPlayFullSurah();
    } else {
      _onDownloadTap();
    }
  }

  void _onPlayFullSurah() {
    final surah = _surah;
    if (surah == null) return;
    final state = _murottalController.value;
    if (state is MurottalPlaying &&
        state.surahNumber == surah.number &&
        state.isFullSurah) {
      _murottalController.pause();
      return;
    }
    if (state is MurottalPaused &&
        state.surahNumber == surah.number &&
        state.isFullSurah) {
      _murottalController.resume();
      return;
    }
    _murottalController.playFullSurah(
      surahNumber: surah.number,
      surahName: surah.transliteration,
      totalAyat: surah.totalVerses,
    );
  }

  /// Tap tombol download di header card.
  /// - Jika sudah tersimpan → tanya hapus
  /// - Jika idle/error → ambil size dulu, tampilkan dialog konfirmasi
  /// - Jika sedang download → batalkan
  Future<void> _onDownloadTap() async {
    final surah = _surah;
    if (surah == null) return;

    final dlState = _downloadController.value;

    // Sudah tersimpan → tawarkan hapus
    if (dlState is DownloadCompleted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Hapus File Tersimpan',
            style: QuranTokens.poppins(
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          content: Text(
            'Hapus file murottal ${surah.transliteration} (${dlState.fileSizeLabel}) dari perangkat?',
            style: QuranTokens.poppins(const TextStyle(fontSize: 14)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Batal',
                  style: QuranTokens.poppins(
                      TextStyle(color: QuranTokens.mutedOf(ctx)))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: QuranTokens.wrongOf(ctx),
                foregroundColor: QuranTokens.onWrongOf(ctx),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Hapus',
                  style: QuranTokens.poppins(
                      const TextStyle(fontWeight: FontWeight.w600))),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _downloadController.deleteDownload(
            _activeQari.id, surah.number);
      }
      return;
    }

    // Sedang download → batalkan
    if (dlState is DownloadInProgress) {
      _downloadController.cancelDownload();
      return;
    }

    // Idle/error → set loading state segera, lalu ambil URL audio
    // Set DownloadCheckingSize dulu agar tombol tampil spinner sebelum API call
    _downloadController.setChecking();
    String? audioUrl;
    try {
      final audioModel =
          await _remoteDatasource.getSurahAudio(surah.number);
      audioUrl = audioModel.audioFull[_activeQari.id];
    } catch (_) {
      _downloadController.setIdle();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengambil informasi audio.',
            style: QuranTokens.poppins(
              TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (audioUrl == null) {
      _downloadController.setIdle();
      return;
    }

    // Cek storage — HEAD request untuk ukuran
    await _downloadController.checkSize(audioUrl);
    if (!mounted) return;

    // Tampilkan dialog
    final url = audioUrl;
    await DownloadProgressDialog.show(
      context: context,
      controller: _downloadController,
      surahName: surah.transliteration,
      onConfirm: () {
        _downloadController.startDownload(
          url: url,
          qariId: _activeQari.id,
          surahNumber: surah.number,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return QuranStatusBar(
      dark: dark,
      child: Scaffold(
        backgroundColor: QuranTokens.background(dark),
        body: SafeArea(
          child: _buildBody(dark),
        ),
      ),
    );
  }

  Widget _buildBody(bool dark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final surah = _surah;
    if (_error != null || surah == null) {
      return _ErrorView(
        message: _error?.message ?? 'Terjadi kesalahan',
        dark: dark,
      );
    }
    return Column(
      children: [
        const SizedBox(height: 12),
        QuranTopBar(
          title: surah.transliteration,
          titleColor: QuranTokens.brandColor(dark),
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: QuranTokens.inkColor(dark),
          ),
          onThemeToggle: () => QuranThemeScope.toggleDark(context),
        ),
        Expanded(
          child: ValueListenableBuilder<MurottalState>(
            valueListenable: _murottalController,
            builder: (context, murottalState, _) {
              return ValueListenableBuilder<DownloadState>(
                valueListenable: _downloadController,
                builder: (context, downloadState, _) {
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    itemCount: surah.verses.length + 2,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          children: [
                            SurahHeaderCard(
                              surah: surah,
                              murottalState: murottalState,
                              downloadState: downloadState,
                              onActionTap: _onHeaderActionTap,
                            ),
                            const SizedBox(height: 24),
                          ],
                        );
                      }
                      if (index == surah.verses.length + 1) {
                        return _SurahNavigation(
                          all: widget.controller.surahs,
                          current: surah,
                          dark: dark,
                        );
                      }
                      final verse = surah.verses[index - 1];
                      final isLastVerse = index == surah.verses.length;
                      final isPlaying = _murottalController.isPlayingAyat(
                        surah.number,
                        verse.numberInSurah,
                      );
                      // Highlight ayat aktif — baik mode full-surah maupun per-ayat
                      final activeAyat = switch (murottalState) {
                        MurottalPlaying(
                          :final surahNumber,
                          :final currentAyat,
                        ) when surahNumber == surah.number =>
                          currentAyat,
                        _ => 0,
                      };
                      final isHighlighted = activeAyat > 0 &&
                          verse.numberInSurah == activeAyat;
                      final verseKey = verse.numberInSurah - 1 < _verseKeys.length
                          ? _verseKeys[verse.numberInSurah - 1]
                          : null;
                      return Padding(
                        key: verseKey,
                        padding: const EdgeInsets.only(
                            bottom: QuranTokens.space8),
                        child: ReadingDwell(
                          recorder: _readingRecorder,
                          itemKey: '${surah.number}:${verse.numberInSurah}',
                          surahNumber: surah.number,
                          verse: verse.numberInSurah,
                          child: VerseView(
                          verse: verse,
                          surahNumber: surah.number,
                          showDivider: !isLastVerse,
                          isPlaying: isPlaying,
                          isHighlighted: isHighlighted,
                          onTap: () => widget.controller
                              .setLastRead(surah.number, verse.numberInSurah),
                          onPlayTap: () =>
                              _onPlayAyat(verse.numberInSurah),
                          onTafsirTap: () =>
                              _openTafsir(verse.numberInSurah),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),

        // Tandai dibaca — hanya untuk bacaan, bukan murottal
        MarkReadButton(onPressed: _markVisibleRead),

        // Mini player — tampil saat audio sedang berjalan
        ValueListenableBuilder<MurottalState>(
          valueListenable: _murottalController,
          builder: (_, murottalState, _) {
            if (murottalState is MurottalIdle) return const SizedBox.shrink();
            return MiniPlayer(controller: _murottalController);
          },
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.dark});

  final String message;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: QuranTokens.poppins(QuranTokens.tsSurahName)
              .copyWith(color: QuranTokens.secondaryColor(dark)),
        ),
      ),
    );
  }
}

/// Navigasi ke surah sebelumnya / sesudahnya.
class _SurahNavigation extends StatelessWidget {
  const _SurahNavigation({
    required this.all,
    required this.current,
    required this.dark,
  });

  final List<Surah> all;
  final Surah current;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final index = all.indexWhere((s) => s.number == current.number);
    final prev = index > 0 ? all[index - 1] : null;
    final next = index < all.length - 1 ? all[index + 1] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _NavButton(
            label: prev?.transliteration ?? '',
            isBack: true,
            enabled: prev != null,
            onTap: prev == null
                ? null
                : () => context.pushReplacement(
                      '/home/quran/surah/${prev.number}',
                    ),
            dark: dark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _NavButton(
            label: next?.transliteration ?? '',
            isBack: false,
            enabled: next != null,
            onTap: next == null
                ? null
                : () => context.pushReplacement(
                      '/home/quran/surah/${next.number}',
                    ),
            dark: dark,
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.isBack,
    required this.enabled,
    required this.dark,
    required this.onTap,
  });

  final String label;
  final bool isBack;
  final bool enabled;
  final bool dark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = QuranTokens.secondaryColor(dark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: QuranTokens.surface(dark),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment:
                isBack ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isBack) ...[
                    Icon(Icons.arrow_back_ios_new,
                        size: 14, color: secondary),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    isBack ? 'Previous' : 'Next',
                    style: QuranTokens.poppins(QuranTokens.tsSurahMeta)
                        .copyWith(color: secondary),
                  ),
                  if (!isBack) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios,
                        size: 14, color: secondary),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: QuranTokens.poppins(QuranTokens.tsSurahName)
                    .copyWith(color: QuranTokens.inkColor(dark)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
