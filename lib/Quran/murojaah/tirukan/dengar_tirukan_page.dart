import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/quran_controller.dart';
import '../../data/datasources/audio_local_datasource.dart';
import '../../data/quran_tokens.dart';
import '../../domain/entities/surah.dart';
import '../../murottal/application/download_controller.dart';
import '../../murottal/application/murottal_controller.dart';
import '../../murottal/application/qari_store.dart';
import '../../murottal/presentation/widgets/download_progress_dialog.dart';
import '../../presentation/widgets/quran_status_bar.dart';
import '../../presentation/widgets/quran_theme_scope.dart';
import '../../presentation/widgets/verse_view.dart';
import '../recite/recite_murojaah_service.dart';
import '../recite/recite_session_controller.dart';
import 'dengar_tirukan_flow.dart';

/// Mode "Dengar lalu Tirukan" (BL-08): ayat diputar, lalu mikrofon menyala.
/// Teks ayat selalu tampil. Orkestrasi ada di [DengarTirukanFlow].
class DengarTirukanPage extends StatefulWidget {
  const DengarTirukanPage({
    super.key,
    required this.surahNumber,
    required this.controller,
    @visibleForTesting this.flowBuilder,
    @visibleForTesting this.serviceBuilder,
    @visibleForTesting this.localDataSource,
  });

  final int surahNumber;
  final QuranController controller;

  /// Pengganti alur produksi (test). Menerima surah yang sudah dimuat.
  final DengarTirukanFlow Function(Surah surah)? flowBuilder;

  /// Pengganti mesin murojaah (test); bila diisi, `initialize()`-nya dijalankan
  /// dan galatnya ditampilkan seperti produksi.
  final ReciteMurojaahService Function(int surahNumber)? serviceBuilder;

  /// Pengganti penyimpanan audio lokal (test).
  final AudioLocalDataSource? localDataSource;

  @override
  State<DengarTirukanPage> createState() => _DengarTirukanPageState();
}

class _DengarTirukanPageState extends State<DengarTirukanPage> {
  Surah? _surah;
  bool _notFound = false;
  DengarTirukanFlow? _flow;
  bool _preparing = true;
  String? _setupError;

  ReciteMurojaahService? _service;
  ReciteSessionController? _session;
  MurottalController? _murottal;

  // Audio hanya dari file lokal: surah harus sudah diunduh sebelum alur mulai.
  late final AudioLocalDataSource _local =
      widget.localDataSource ?? AudioLocalDataSourceImpl();
  late final DownloadController _download =
      DownloadController(localDataSource: _local);
  QariStore _qariStore = QariStore.defaults();
  bool _needsDownload = false;

  @override
  void initState() {
    super.initState();
    unawaited(_setup());
  }

  Future<void> _setup() async {
    if (widget.controller.surahs.isEmpty) await widget.controller.load();
    final surah = widget.controller.surahs
        .where((s) => s.number == widget.surahNumber)
        .firstOrNull;
    if (!mounted) return;
    if (surah == null) {
      setState(() {
        _notFound = true;
        _preparing = false;
      });
      return;
    }
    _surah = surah;
    unawaited(_loadLatin());
    final build = widget.flowBuilder;
    final makeService = widget.serviceBuilder;
    if (build == null) {
      _qariStore = QariStore(await SharedPreferences.getInstance());
      final ok = await _local.isSurahComplete(
          _qariStore.getSelectedQari().id, surah.number, surah.totalVerses);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _needsDownload = true;
          _preparing = false;
        });
        return;
      }
    }
    if (build != null && makeService == null) {
      _flow = build(surah);
    } else {
      final service = _service =
          makeService?.call(surah.number) ??
          ReciteMurojaahService(surahNumber: surah.number);
      final session = _session = ReciteSessionController(engine: service);
      if (build != null) {
        _flow = build(surah);
      } else {
        final murottal = _murottal = MurottalController(
          localDataSource: _local,
          qariStore: _qariStore,
        );
        await murottal.prefsLoaded;
        _flow = DengarTirukanFlow(
          totalAyat: surah.totalVerses,
          recognizer: ReciteAyatRecognizer(session: session, engine: service),
          gap: () => Duration(seconds: murottal.repeat.value.gapSeconds),
          stopAudio: murottal.stop,
          playAyat: (ayat) => murottal.playOnce(
            surahNumber: surah.number,
            surahName: surah.transliteration,
            ayatNumber: ayat,
            totalAyat: surah.totalVerses,
          ),
        );
      }
      if (!await _initService(service)) return;
    }
    setState(() => _preparing = false);
    unawaited(_flow!.start());
  }

  /// Dipicu pengguna: unduh audio surah, lalu mulai alur dari awal.
  Future<void> _downloadAudio() async {
    final surah = _surah;
    if (surah == null) return;
    await DownloadProgressDialog.run(
      context: context,
      controller: _download,
      qariId: _qariStore.getSelectedQari().id,
      surahNumber: surah.number,
      verseCount: surah.totalVerses,
      surahName: surah.transliteration,
      notice: 'Surah ini belum diunduh.',
    );
    if (!mounted || _download.value is! DownloadCompleted) return;
    setState(() {
      _needsDownload = false;
      _preparing = true;
    });
    unawaited(_setup());
  }

  /// Siapkan mesin/unduh model. Gagal: tampilkan sebabnya, jangan mulai alur
  /// (kalau tidak, pesan umum "audio atau mikrofon" yang muncul).
  Future<bool> _initService(ReciteMurojaahService service) async {
    await service.initialize();
    if (!mounted) return false;
    final err = service.errorMessage.value;
    if (service.status.value == ReciteMurojaahStatus.error && err != null) {
      setState(() {
        _setupError = err;
        _preparing = false;
      });
      return false;
    }
    return true;
  }

  /// Dipicu pengguna: service yang sama aman dipakai ulang (initialize()
  /// mereset dirinya saat gagal; unduhan menghapus .tmp lama).
  Future<void> _retrySetup() async {
    final service = _service;
    if (service == null) return;
    setState(() {
      _setupError = null;
      _preparing = true;
    });
    if (!await _initService(service)) return;
    setState(() => _preparing = false);
    unawaited(_flow!.start());
  }

  /// Latin (BC-01) menyusul setelah ayat tampil; gagal/offline = tanpa latin.
  Future<void> _loadLatin() async {
    final surah = await widget.controller.loadLatin(widget.surahNumber);
    if (mounted && surah != null) setState(() => _surah = surah);
  }

  @override
  void dispose() {
    // Hentikan audio & mikrofon dulu; baru lepaskan semua sumber dayanya.
    final flow = _flow;
    final service = _service;
    final session = _session;
    final murottal = _murottal;
    (flow?.stop() ?? Future<void>.value()).whenComplete(() {
      flow?.dispose();
      session?.dispose();
      unawaited(service?.dispose());
      murottal?.dispose();
      _download.dispose();
    });
    super.dispose();
  }

  String _status(TirukanPhase p) => switch (p) {
    TirukanPhase.idle => 'Dihentikan',
    TirukanPhase.listening => 'Dengarkan…',
    TirukanPhase.gap => 'Bersiap…',
    TirukanPhase.recording => 'Giliranmu, tirukan…',
    TirukanPhase.correct => 'Benar! Lanjut',
    TirukanPhase.retry => 'Coba lagi',
    TirukanPhase.finished => 'Selesai',
    TirukanPhase.error => 'Ada masalah (audio atau mikrofon). Coba lagi.',
  };

  IconData _icon(TirukanPhase p) => switch (p) {
    TirukanPhase.listening => Icons.hearing,
    TirukanPhase.gap => Icons.hourglass_empty,
    TirukanPhase.recording => Icons.mic,
    TirukanPhase.correct || TirukanPhase.finished => Icons.check_circle_outline,
    TirukanPhase.retry => Icons.replay,
    TirukanPhase.error => Icons.info_outline,
    TirukanPhase.idle => Icons.pause_circle_outline,
  };

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return QuranStatusBar(
      dark: dark,
      child: Scaffold(
        backgroundColor: QuranTokens.background(dark),
        appBar: AppBar(
          backgroundColor: QuranTokens.background(dark),
          foregroundColor: QuranTokens.inkColor(dark),
          elevation: 0,
          title: Text(
            _surah == null
                ? 'Dengar lalu Tirukan'
                : 'Dengar lalu Tirukan · ${_surah!.transliteration}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: QuranTokens.poppins(QuranTokens.tsAppTitle).copyWith(
              color: QuranTokens.brandColor(dark),
              fontSize: 18,
            ),
          ),
        ),
        body: SafeArea(child: _body(dark)),
      ),
    );
  }

  ButtonStyle _buttonStyle(bool dark) => FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    backgroundColor: QuranTokens.brandColor(dark),
    foregroundColor: QuranTokens.onPrimaryColor(dark),
    textStyle: QuranTokens.poppins(
      const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  Widget _body(bool dark) {
    final flow = _flow;
    final surah = _surah;
    if (_notFound) return const Center(child: Text('Surah tidak ditemukan'));
    if (_needsDownload) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Surah ini belum diunduh. Unduh dulu agar bisa dipakai tanpa internet.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => unawaited(_downloadAudio()),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Unduh'),
                style: _buttonStyle(dark),
              ),
            ],
          ),
        ),
      );
    }
    final setupError = _setupError;
    if (setupError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(setupError, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => unawaited(_retrySetup()),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
                style: _buttonStyle(dark),
              ),
            ],
          ),
        ),
      );
    }
    if (_preparing || flow == null || surah == null) {
      final service = _service;
      if (service == null) {
        return const Center(child: CircularProgressIndicator());
      }
      // Unduh model ±70 MB: tampilkan kemajuan, bukan spinner kosong.
      return Center(
        child: ListenableBuilder(
          listenable: Listenable.merge([service.status, service.downloadProgress]),
          builder: (context, _) {
            final downloading =
                service.status.value == ReciteMurojaahStatus.downloadingModel;
            final p = service.downloadProgress.value;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (downloading) ...[
                    Text(
                      'Mengunduh model suara… ${(p * 100).toInt()}%',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: p > 0 ? p : null),
                  ] else
                    const CircularProgressIndicator(),
                ],
              ),
            );
          },
        ),
      );
    }
    return ListenableBuilder(
      listenable: flow,
      builder: (context, _) {
        final verse = surah.verses[flow.ayat - 1];
        final phase = flow.phase;
        final running = phase != TirukanPhase.idle &&
            phase != TirukanPhase.finished &&
            phase != TirukanPhase.error;
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: VerseView(
                  verse: verse,
                  surahNumber: surah.number,
                  showDivider: false,
                  isHighlighted: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    liveRegion: true,
                    label: 'Ayat ${flow.ayat} dari ${surah.totalVerses}. '
                        '${_status(phase)}',
                    excludeSemantics: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _icon(phase),
                          size: 22,
                          color: QuranTokens.brandColor(dark),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${_status(phase)} · Ayat ${flow.ayat}/${surah.totalVerses}',
                            textAlign: TextAlign.center,
                            style: QuranTokens.poppins(
                              TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: QuranTokens.inkColor(dark),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: running
                        ? () => unawaited(flow.stop())
                        : phase == TirukanPhase.finished
                            ? null
                            : () => unawaited(flow.start()),
                    icon: Icon(running ? Icons.stop : Icons.play_arrow),
                    label: Text(running ? 'Berhenti' : 'Mulai lagi'),
                    style: _buttonStyle(dark),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
