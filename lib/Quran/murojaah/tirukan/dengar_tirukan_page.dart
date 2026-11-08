import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/quran_controller.dart';
import '../../data/datasources/equran_remote_datasource.dart';
import '../../data/quran_tokens.dart';
import '../../domain/entities/surah.dart';
import '../../murottal/application/murottal_controller.dart';
import '../../murottal/application/qari_store.dart';
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
  });

  final int surahNumber;
  final QuranController controller;

  /// Pengganti alur produksi (test). Menerima surah yang sudah dimuat.
  final DengarTirukanFlow Function(Surah surah)? flowBuilder;

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
    if (build != null) {
      _flow = build(surah);
    } else {
      final service = _service = ReciteMurojaahService(
        surahNumber: surah.number,
      );
      final session = _session = ReciteSessionController(engine: service);
      final murottal = _murottal = MurottalController(
        datasource: EquranRemoteDataSourceImpl(),
        qariStore: QariStore.defaults(),
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
      await service.initialize();
      if (!mounted) return;
      // Gagal siapkan mesin/unduh model: tampilkan sebabnya, jangan mulai alur
      // (kalau tidak, pesan umum "audio atau mikrofon" yang muncul).
      final err = service.errorMessage.value;
      if (service.status.value == ReciteMurojaahStatus.error && err != null) {
        setState(() {
          _setupError = err;
          _preparing = false;
        });
        return;
      }
    }
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

  Widget _body(bool dark) {
    final flow = _flow;
    final surah = _surah;
    if (_notFound) return const Center(child: Text('Surah tidak ditemukan'));
    final setupError = _setupError;
    if (setupError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(setupError, textAlign: TextAlign.center),
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
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: QuranTokens.brandColor(dark),
                      foregroundColor: QuranTokens.onPrimaryColor(dark),
                      textStyle: QuranTokens.poppins(
                        const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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
