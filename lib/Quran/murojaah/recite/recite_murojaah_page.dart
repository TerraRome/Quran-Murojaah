import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/quran_tokens.dart';
import '../../presentation/widgets/quran_status_bar.dart';
import '../../presentation/widgets/quran_theme_scope.dart';
import '../progress/progress_controller.dart';
import 'recite_murojaah_service.dart';
import 'recite_progress_recorder.dart';
import 'recite_session_controller.dart';
import 'widgets/recite_controls.dart';
import 'widgets/recite_correction_sheet.dart';
import 'widgets/recite_finish_screen.dart';
import 'widgets/recite_mushaf.dart';
import 'widgets/recite_onboarding.dart';
import 'widgets/recite_surah_picker.dart';

/// Halaman Murojaah baru: mushaf tersembunyi yang terbuka ayat demi ayat
/// berdasarkan hasil pelacakan `recite_quran`.
///
/// Halaman memegang lifecycle service (create → initialize → dispose); seluruh
/// state sesi dan keputusan penilaian ada di [ReciteSessionController].
class ReciteMurojaahPage extends StatefulWidget {
  const ReciteMurojaahPage({
    super.key,
    required this.surahNumber,
    this.progress,
  });

  final int surahNumber;

  /// Pencatat progres. Null = sesi berjalan tanpa mencatat apa pun (dipakai
  /// pratinjau dan test yang tidak peduli progres).
  final MurojaahProgressController? progress;

  @override
  State<ReciteMurojaahPage> createState() => _ReciteMurojaahPageState();
}

class _ReciteMurojaahPageState extends State<ReciteMurojaahPage>
    with WidgetsBindingObserver {
  late final ReciteMurojaahService _service;
  late final ReciteSessionController _session;
  late ReciteProgressRecorder _recorder;

  /// Layar selesai sedang tampil (surah tamat atau sesi dihentikan manual).
  bool _finishVisible = false;

  /// Layar selesai yang tampil karena surah tamat, bukan karena dihentikan.
  bool _surahComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = ReciteMurojaahService(surahNumber: widget.surahNumber);
    _session = ReciteSessionController(engine: _service);
    _recorder = ReciteProgressRecorder(
      progress: widget.progress,
      surahNumber: widget.surahNumber,
    );
    _service.status.addListener(_onStatus);
    _session.addListener(_onSessionChanged);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.status.removeListener(_onStatus);
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    unawaited(_service.dispose());
    super.dispose();
  }

  /// Aplikasi ditinggalkan: catat progres sekarang, jangan tunggu sesi berhenti.
  ///
  /// Proses bisa dibunuh sistem saat di background, jadi ini kesempatan terakhir
  /// menyelamatkan progres. Recorder mencegah ayat tercatat dua kali.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) unawaited(_recordProgress());
  }

  void _onSessionChanged() {
    if (!_session.isComplete || _finishVisible) return;
    unawaited(_recordProgress(showFinish: true, surahComplete: true));
  }

  /// Catat ayat yang sudah terbaca penuh, sebagai rentang berurutan.
  ///
  /// Dipanggil saat sesi berhenti, surah tamat, atau aplikasi masuk background —
  /// bukan per kata, supaya log tidak membengkak dan XP tetap per ayat.
  ///
  /// [showFinish] hanya untuk dua peristiwa yang layak dirayakan: surah tamat
  /// dan sesi dihentikan setelah minimal satu ayat tercatat. Pencatatan karena
  /// aplikasi masuk background tidak boleh memunculkan layar selesai.
  Future<void> _recordProgress({
    bool showFinish = false,
    bool surahComplete = false,
  }) async {
    await _recorder.record(_session);
    if (!mounted || !showFinish) return;
    final hasSomething = _recorder.recordedCount > 0;
    if (!hasSomething && !surahComplete) return;
    setState(() {
      _surahComplete = surahComplete;
      _finishVisible = true;
    });
  }

  /// "Lanjut": teruskan latihan dari keadaan sekarang.
  ///
  /// Surah tamat → lanjut ke surah berikutnya (atau kembali ke daftar di akhir
  /// mushaf). Dihentikan manual → lanjut mendengarkan lagi tanpa mengulang.
  void _onContinue() {
    setState(() => _finishVisible = false);
    if (!_surahComplete) {
      unawaited(_service.startListening());
      return;
    }
    final next = widget.surahNumber + 1;
    if (next > _totalSurahs) {
      if (context.canPop()) context.pop();
      return;
    }
    context.pushReplacement('/home/quran/murojaah/surah/$next');
  }

  /// "Ulangi surah": mulai dari ayat pertama, catatan sesi ikut direset supaya
  /// ayat yang diulang tetap bisa memberi XP pada hari berikutnya.
  void _onRepeat() {
    _session.resetAll();
    _recorder = ReciteProgressRecorder(
      progress: widget.progress,
      surahNumber: widget.surahNumber,
    );
    setState(() {
      _finishVisible = false;
      _surahComplete = false;
    });
  }

  void _onPickSurah() => _pickSurah(QuranThemeScope.darkOf(context));

  /// Jumlah surah dalam mushaf — batas atas "lanjut ke surah berikutnya".
  static const _totalSurahs = 114;

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

  void _adoptVerses() {
    if (!_session.adoptVerses()) return;
    if (!mounted) return;
    unawaited(_maybeOnboard());
  }

  /// Sheet koreksi: kata yang diharapkan vs yang terdengar.
  void _showCorrection(int wordId) {
    unawaited(
      showReciteCorrectionSheet(
        context,
        expected: _session.wordText(wordId),
        heard: _session.heardOf(wordId),
        dark: QuranThemeScope.darkOf(context),
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (_service.status.value == ReciteMurojaahStatus.listening) {
      await _service.stopListening();
      // Sesi berhenti = kesempatan mencatat ayat yang sudah tuntas, sekaligus
      // menutup latihan dengan ringkasan bila ada yang tercatat.
      await _recordProgress(showFinish: true);
      return;
    }
    if (_service.status.value == ReciteMurojaahStatus.error) {
      await _initialize();
      return;
    }
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
          child: ListenableBuilder(
            listenable: _session,
            builder: (context, _) => Column(
              children: [
                _Header(
                  dark: dark,
                  title: _title,
                  onHelp: _showHelp,
                  onPickSurah: _session.verses.isEmpty
                      ? null
                      : () => _pickSurah(dark),
                  showSubtitle: _session.verses.isNotEmpty,
                ),
                Expanded(
                  child: _finishVisible
                      ? _finish()
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _session.verses.isEmpty
                              ? _placeholder(dark)
                              : _mushaf(dark),
                        ),
                ),
                if (!_finishVisible) _bottom(dark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _title => _session.verses.isEmpty
      ? 'Latihan hafalan'
      : _session.verses.first.surahNameEn.isNotEmpty
      ? _session.verses.first.surahNameEn
      : _session.verses.first.surahName;

  /// Panduan singkat — juga pintu untuk ganti surah.
  void _showHelp() {
    unawaited(
      showReciteOnboarding(
        context,
        dark: QuranThemeScope.darkOf(context),
        onChangeSurah: () {
          // Tutup panduan, lalu buka daftar surah.
          Navigator.of(context).maybePop();
          unawaited(
            showReciteSurahPicker(
              context,
              dark: QuranThemeScope.darkOf(context),
              current: widget.surahNumber,
            ),
          );
        },
      ),
    );
  }

  void _pickSurah(bool dark) {
    unawaited(
      showReciteSurahPicker(context, dark: dark, current: widget.surahNumber),
    );
  }

  /// Panduan otomatis sekali, hanya setelah ayat siap.
  Future<void> _maybeOnboard() async {
    if (await reciteOnboardingSeen()) return;
    if (!mounted || _session.verses.isEmpty) return;
    _showHelp();
  }

  Widget _placeholder(bool dark) {
    return ValueListenableBuilder<ReciteMurojaahStatus>(
      valueListenable: _service.status,
      builder: (context, status, _) {
        final loading = status != ReciteMurojaahStatus.error;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator()
              else
                Icon(
                  Icons.cloud_off_outlined,
                  size: 44,
                  color: QuranTokens.textMuted(dark),
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ReciteStatusChip(
                  status: status,
                  message: _service.errorMessage.value,
                  dark: dark,
                  showHint: true,
                ),
              ),
              if (!loading) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _initialize,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Coba lagi'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(160, 48),
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
            ],
          ),
        );
      },
    );
  }

  Widget _mushaf(bool dark) {
    final totalWords = _session.totalWords;
    return Column(
      children: [
        _progress(dark, totalWords, _session.verses.length),
        const SizedBox(height: 6),
        _legend(dark),
        const SizedBox(height: 6),
        Expanded(
          child: ReciteMushaf(
            verses: _session.verses,
            matched: _session.matched,
            missed: _session.missed,
            activeVerse: _session.activeVerse,
            peekWord: _session.peekWord,
            onWordTap: (id) {
              if (_session.missed.contains(id)) _showCorrection(id);
            },
          ),
        ),
      ],
    );
  }

  /// Keterangan tanda: warna tidak pernah jadi satu-satunya penanda.
  Widget _legend(bool dark) {
    Widget item(IconData icon, String text, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: QuranTokens.poppins(TextStyle(fontSize: 14, color: color)),
        ),
      ],
    );
    return Row(
      children: [
        item(Icons.check_circle_outline, 'Benar', QuranTokens.correct(dark)),
        const SizedBox(width: 14),
        item(Icons.gesture, 'Perlu diulang', QuranTokens.wrong(dark)),
        const Spacer(),
        if (_session.peekCount > 0)
          Text(
            '${_session.peekCount} kali intip',
            style: QuranTokens.poppins(
              TextStyle(fontSize: 14, color: QuranTokens.textMuted(dark)),
            ),
          ),
      ],
    );
  }

  /// Progres dalam kalimat biasa: "Ayat 2 dari 7 · Akurasi 96%".
  Widget _progress(bool dark, int totalWords, int verseCount) {
    final percent = totalWords == 0
        ? 0.0
        : _session.matched.length / totalWords;
    final accuracy = (_session.accuracy * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Ketepatan bacaan $accuracy persen dari percobaan',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: QuranTokens.border(dark),
              valueColor: AlwaysStoppedAnimation(QuranTokens.brandColor(dark)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                totalWords == 0
                    ? 'Menyiapkan kata…'
                    : 'Ayat ${_session.activeVerse + 1} dari $verseCount'
                          ' · Akurasi $accuracy%',
                style: QuranTokens.poppins(
                  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: QuranTokens.inkColor(dark),
                  ),
                ),
              ),
            ),
            ReciteActionButton(
              icon: Icons.visibility_outlined,
              label: 'Intip kata',
              dark: dark,
              compact: true,
              onTap: _session.peek,
            ),
          ],
        ),
      ],
    );
  }

  /// Layar selesai: perayaan + ringkasan + jalan keluar.
  ///
  /// Memakai [ReciteFinishScreen] yang sama untuk dua pemicu — surah tamat dan
  /// sesi dihentikan manual — supaya tidak ada dua layar selesai yang berbeda
  /// cerita.
  Widget _finish() {
    final total = _session.verses.length;
    var done = 0;
    for (var verse = 0; verse < total; verse++) {
      if (_session.isVerseComplete(verse)) done++;
    }
    return ReciteFinishScreen(
      surahName: _title,
      versesDone: done,
      totalVerses: total,
      accuracyPercent: (_session.accuracy * 100).round(),
      peekCount: _session.peekCount,
      result: _recorder.result,
      surahComplete: _surahComplete,
      onContinue: _onContinue,
      onPickSurah: _onPickSurah,
      onRepeat: _onRepeat,
    );
  }

  Widget _bottom(bool dark) {
    final grey = QuranTokens.textMuted(dark);
    final red = QuranTokens.wrong(dark);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: ValueListenableBuilder<ReciteMurojaahStatus>(
          valueListenable: _service.status,
          builder: (context, status, _) {
            final listening = status == ReciteMurojaahStatus.listening;
            final busy =
                status == ReciteMurojaahStatus.preparing ||
                status == ReciteMurojaahStatus.downloadingModel;
            final done = _session.isComplete;
            final retrying = _session.activeVerseMissed;
            final error = status == ReciteMurojaahStatus.error;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _errorNotice(dark),
                  )
                else if (retrying)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 18, color: red),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Ada kata yang perlu diulang',
                            style: QuranTokens.poppins(
                              TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: red,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_session.verses.isNotEmpty && !done)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ReciteStatusChip(
                      status: status,
                      message: _service.errorMessage.value,
                      dark: dark,
                      showHint: true,
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
                // Saat selesai, ajakan mengulang ada di kartu "selesai" di atas.
                if (error)
                  FilledButton.icon(
                    onPressed: _initialize,
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('Coba lagi'),
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
                  )
                else if (!done)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: ReciteActionButton(
                          icon: Icons.restart_alt,
                          label: 'Mulai dari awal',
                          dark: dark,
                          onTap:
                              _session.matched.isEmpty &&
                                  _session.missed.isEmpty
                              ? null
                              : _session.resetAll,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ReciteMicButton(
                          listening: listening,
                          enabled: !busy,
                          dark: dark,
                          onTap: _toggleListening,
                        ),
                      ),
                      Flexible(
                        child: ReciteActionButton(
                          icon: Icons.refresh,
                          label: 'Ulang ayat ini',
                          dark: dark,
                          urgency: retrying ? red : null,
                          onTap: retrying ? _session.retryCurrentVerse : null,
                        ),
                      ),
                    ],
                  ),
                if (!done && !error)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      listening
                          ? 'Baca pelan-pelan. Kata akan terbuka sendiri.'
                          : 'Tekan mikrofon, lalu baca ayat yang tampil.',
                      textAlign: TextAlign.center,
                      style: QuranTokens.poppins(
                        TextStyle(fontSize: 14, color: grey),
                      ),
                    ),
                  ),
                if (!done && _session.missed.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Ketuk kata bergaris merah untuk melihat koreksi.',
                      textAlign: TextAlign.center,
                      style: QuranTokens.poppins(
                        TextStyle(fontSize: 14, color: grey),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Pesan galat ramah; detail teknis disembunyikan di balik "Lihat detail".
  Widget _errorNotice(bool dark) {
    final red = QuranTokens.wrong(dark);
    final detail = _service.errorMessage.value;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: red.withValues(alpha: dark ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: red.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ada masalah kecil. Coba lagi.',
                  style: QuranTokens.poppins(
                    TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: QuranTokens.inkColor(dark),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (detail != null && detail.isNotEmpty)
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 6),
                iconColor: QuranTokens.textMuted(dark),
                collapsedIconColor: QuranTokens.textMuted(dark),
                title: Text(
                  'Lihat detail',
                  style: QuranTokens.poppins(
                    TextStyle(fontSize: 14, color: QuranTokens.textMuted(dark)),
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      detail,
                      style: QuranTokens.poppins(
                        TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: QuranTokens.textMuted(dark),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Header: kembali, nama surah, panduan, tema.
class _Header extends StatelessWidget {
  const _Header({
    required this.dark,
    required this.title,
    required this.onHelp,
    this.onPickSurah,
    this.showSubtitle = false,
  });

  final bool dark;
  final String title;
  final VoidCallback onHelp;
  final VoidCallback? onPickSurah;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    final ink = QuranTokens.inkColor(dark);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: ink,
            tooltip: 'Kembali',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: EdgeInsets.zero,
          ),
          Expanded(
            child: Semantics(
              button: onPickSurah != null,
              label: onPickSurah == null
                  ? title
                  : '$title. Ketuk untuk memilih surah lain.',
              child: InkWell(
                onTap: onPickSurah,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: QuranTokens.poppins(QuranTokens.tsAppTitle)
                                  .copyWith(
                                    color: QuranTokens.brandColor(dark),
                                    fontSize: 18,
                                  ),
                            ),
                            if (showSubtitle)
                              Text(
                                'Latihan hafalan',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: QuranTokens.poppins(
                                  TextStyle(
                                    fontSize: 14,
                                    color: QuranTokens.textMuted(dark),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (onPickSurah != null)
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 20,
                          color: QuranTokens.brandColor(dark),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onHelp,
            icon: const Icon(Icons.help_outline, size: 22),
            color: ink,
            tooltip: 'Cara pakai',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            onPressed: () => QuranThemeScope.toggleDark(context),
            icon: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 22,
            ),
            color: ink,
            tooltip: dark ? 'Mode terang' : 'Mode gelap',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
