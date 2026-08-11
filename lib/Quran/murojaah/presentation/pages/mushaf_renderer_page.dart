import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../application/quran_controller.dart';
import '../../../data/quran_tokens.dart';
import '../../../domain/entities/surah.dart';
import '../../../domain/entities/verse.dart';
import '../../../domain/failures/quran_failure.dart';
import '../../../presentation/widgets/quran_status_bar.dart';
import '../../../presentation/widgets/quran_theme_scope.dart';
import '../../../presentation/widgets/quran_top_bar.dart';
import '../../application/arabic_matcher.dart';
import '../../application/murojaah_controller.dart';
import '../../application/murojaah_recitation_session.dart';
import '../../application/verse_speaker.dart';
import '../widgets/murojaah_mushaf.dart';

/// Halaman renderer mushaf Murojaah (Milestone 2-5).
///
/// Alur: user menekan **Mulai Murojaah** (semua ayat tersembunyi, ayat aktif
/// 1). Tombol **Bicara** mengaktifkan speech recognition; transkrip final
/// divalidasi otomatis terhadap ayat aktif (Matching Engine). Benar → ayat
/// ter-reveal & maju. Salah ke-3 pada ayat yang sama → TTS membacakan ayat
/// yang benar; user tetap di ayat tersebut dan boleh mencoba lagi.
class MushafRendererPage extends StatefulWidget {
  const MushafRendererPage({
    super.key,
    required this.surahNumber,
    required this.controller,
    required this.recitationSession,
    this.verseSpeaker,
  });

  final int surahNumber;
  final QuranController controller;

  /// Pembaca ayat (TTS); default [FlutterTtsVerseSpeaker]. Dapat di-fake.
  final VerseSpeaker? verseSpeaker;

  /// Pipeline ASR on-device. Page tidak memiliki session ini —
  /// caller bertanggung jawab atas dispose()-nya.
  final MurojaahRecitationSession recitationSession;

  @override
  State<MushafRendererPage> createState() => _MushafRendererPageState();
}

class _MushafRendererPageState extends State<MushafRendererPage> {
  final MurojaahController _murojaah = MurojaahController();
  late final VerseSpeakerSession _speaker;

  // ── ASR session ────────────────────────────────────────────────────────────
  late final MurojaahRecitationSession _recitationSession;
  StreamSubscription<RecitationSessionEvent>? _sessionEventSub;

  // ── E6: Continuous-listening state ─────────────────────────────────────────
  /// True between ACCEPT and the moment the new session actually starts.
  /// Guards against duplicate auto-starts and stale timer callbacks.
  bool _pendingAutoAdvance = false;

  /// 800 ms delay timer between ACCEPT and the next session.start().
  /// Cancelled on manual stop, completion, dispose, and Ulang.
  Timer? _autoAdvanceTimer;

  /// True when the 800 ms timer fired but TTS was speaking at that moment,
  /// so the restart was deferred. Cleared when TTS finishes and we restart,
  /// or when _cancelAutoAdvance() is called.
  bool _ttsBlockedAutoRestart = false;

  Surah? _surah;
  bool _loading = true;
  QuranFailure? _error;

  @override
  void initState() {
    super.initState();
    _speaker = VerseSpeakerSession(widget.verseSpeaker ?? FlutterTtsVerseSpeaker());
    _murojaah.addListener(_onMurojaahChanged);
    _speaker.addListener(_onSpeakerChanged);

    // Wire recitation session.
    _recitationSession = widget.recitationSession;
    _sessionEventSub = _recitationSession.events.listen(_onSessionEvent);
    _recitationSession.addListener(_onSessionStateChanged);

    _load();
  }

  @override
  void dispose() {
    // Cancel auto-advance timer FIRST to prevent callbacks after dispose.
    _cancelAutoAdvance();

    // Cancel event subscription to prevent callbacks after dispose.
    _sessionEventSub?.cancel();
    _sessionEventSub = null;

    _recitationSession.removeListener(_onSessionStateChanged);
    // Stop to release microphone. Page does not own the session — no dispose().
    _recitationSession.stop();

    _speaker.removeListener(_onSpeakerChanged);
    _murojaah.removeListener(_onMurojaahChanged);
    _speaker.dispose();
    _murojaah.dispose();
    super.dispose();
  }

  /// Cancel any pending auto-advance timer and clear all pending flags.
  /// Safe to call multiple times.
  void _cancelAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
    _pendingAutoAdvance = false;
    _ttsBlockedAutoRestart = false;
  }

  // ── Session listeners ──────────────────────────────────────────────────────

  /// Rebuild when session state changes (status transitions: initializing →
  /// listening → processing → result / error / permissionDenied).
  void _onSessionStateChanged() {
    if (mounted) setState(() {});
  }

  /// Handle discrete session events.
  void _onSessionEvent(RecitationSessionEvent event) {
    switch (event) {
      case MatchingCompleted():
        _onMatchingCompleted(event);
      case SessionStopped():
        // After ACCEPT the session stops itself. If _pendingAutoAdvance is set,
        // start the 800 ms timer now that the session is fully torn down.
        if (_pendingAutoAdvance) {
          _pendingAutoAdvance = false;
          _autoAdvanceTimer = Timer(
            const Duration(milliseconds: 800),
            _onAutoAdvanceTimer,
          );
        }
      case SessionError():
        // State already updated via ChangeNotifier; rebuild is triggered by
        // _onSessionStateChanged. No additional action needed here.
        if (mounted) setState(() {});
      default:
        // SpeechStarted, SpeechEnded, UtteranceReady, etc. — no page action.
        break;
    }
  }

  /// Called when [MatchingCompleted] arrives from the ASR pipeline.
  ///
  /// Reads the transcript from session state (set before the event fires),
  /// delegates validation to [MurojaahController.validateWithMatcher], and
  /// fires TTS help if needed.
  ///
  /// On ACCEPT: sets [_pendingAutoAdvance] so that when [SessionStopped]
  /// arrives (the session tears itself down after accept), the 800 ms
  /// auto-advance timer is armed.
  void _onMatchingCompleted(MatchingCompleted event) {
    if (!mounted) return;
    if (!_murojaah.value.isRunning) return;
    final surah = _surah;
    if (surah == null) return;
    final active = _murojaah.value.activeVerse;
    if (active == null) return;

    // Transcript is stored in session state before the event is emitted.
    final transcript =
        _recitationSession.state.lastAsrResult?.transcript ?? '';
    if (transcript.isEmpty) return;

    final verse = surah.verses[active - 1];
    final correct = _murojaah.validateWithMatcher(
      transcript: transcript,
      expectedArabic: verse.displayArabic(surah.number),
      surahNumber: surah.number,
      totalVerses: surah.verses.length,
    );

    if (correct) {
      // ACCEPT path: arm the auto-advance flag. The session will emit
      // SessionStopped after its internal _tearDown(); _onSessionEvent
      // will then start the 800 ms timer.
      _pendingAutoAdvance = true;
    } else if (_murojaah.shouldTriggerHelp) {
      final tts = _ttsText(verse);
      if (tts.isNotEmpty) _speaker.speak(tts);
    }
  }

  /// Called when the 800 ms auto-advance timer fires after an ACCEPT.
  ///
  /// Guards: widget must still be mounted, murojaah must still be running
  /// (not completed / stopped), and the active verse must still be set.
  /// If TTS is speaking we set [_ttsBlockedAutoRestart] and defer —
  /// [_onSpeakerChanged] will call [_startRecitationSession] when TTS finishes.
  void _onAutoAdvanceTimer() {
    _autoAdvanceTimer = null;
    if (!mounted) return;
    if (_murojaah.value.phase != MurojaahPhase.running) return;
    if (_murojaah.value.activeVerse == null) return;
    if (_speaker.value == VerseSpeakerStatus.speaking) {
      // TTS is playing — defer restart until TTS finishes.
      _ttsBlockedAutoRestart = true;
      return;
    }
    _startRecitationSession();
  }

  /// When TTS starts speaking, stop the ASR session to avoid mic/speaker
  /// conflict.
  ///
  /// When TTS finishes and [_ttsBlockedAutoRestart] is set (the 800 ms timer
  /// fired while TTS was playing), immediately start the next session.
  void _onSpeakerChanged() {
    if (_speaker.value == VerseSpeakerStatus.speaking) {
      // TTS starting: stop mic to avoid feedback.
      _recitationSession.stop();
    } else {
      // TTS finished: resume a deferred auto-restart if one is pending.
      if (!mounted) return;
      if (_ttsBlockedAutoRestart) {
        _ttsBlockedAutoRestart = false;
        if (_murojaah.value.phase == MurojaahPhase.running &&
            _murojaah.value.activeVerse != null) {
          _startRecitationSession();
        }
      }
    }
  }

  void _onMurojaahChanged() {
    if (_murojaah.value.phase == MurojaahPhase.completed) {
      _cancelAutoAdvance();
      _recitationSession.stop();
    }
  }

  /// Dipanggil tombol "Selesai" — validasi akumulasi transkrip saat ini.
  /// Benar → reveal & maju. Salah → feedback incorrect, akumulasi direset
  /// agar user bisa mulai rekam ulang dari awal untuk ayat yang sama.
  void _submitAccumulated() {
    _cancelAutoAdvance();
    final state = _murojaah.value;
    final surah = _surah;
    final active = state.activeVerse;
    if (!state.isRunning || active == null || surah == null) return;
    if (!_murojaah.hasAccumulated) return;

    final verse = surah.verses[active - 1];
    final correct = _murojaah.validate(
      transcript: _murojaah.accumulatedTranscript,
      expectedArabic: verse.displayArabic(surah.number),
      verseNormalized: verse.normalizedText,
      surahNumber: surah.number,
      totalVerses: surah.verses.length,
    );

    if (!correct) {
      // Reset akumulasi agar user mulai bersih di rekaman berikutnya
      _murojaah.clearAccumulated();
      if (_murojaah.shouldTriggerHelp) {
        final tts = _ttsText(verse);
        if (tts.isNotEmpty) _speaker.speak(tts);
      }
    }
  }

  /// Teks untuk TTS: transliteration Latin bila tersedia, fallback ke expandForTts.
  /// Strip notasi waqf (a)/(i)/(u) agar tidak dibaca TTS.
  String _ttsText(Verse verse) {
    final latin = verse.transliteration.trim();
    if (latin.isNotEmpty) {
      return latin
          .replaceAll(RegExp(r'\([aiu]\)'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
    return ArabicMatcher.expandForTts(verse.arabic);
  }

  /// Start the recitation session for the current active verse.
  /// Called when "Bicara" is tapped while the session is idle, or when
  /// "Mulai Murojaah" / "Ulang" starts a fresh run.
  Future<void> _startRecitationSession() async {
    final surah = _surah;
    if (surah == null) return;
    final active = _murojaah.value.activeVerse;
    if (active == null) return;
    final verse = surah.verses[active - 1];
    await _recitationSession.start(
      MurojaahSessionConfig(
        expectedArabic: verse.displayArabic(surah.number),
      ),
    );
  }

  /// Stop the recitation session (microphone released). Cancels any pending
  /// auto-advance timer. Safe to call when idle.
  Future<void> _stopRecitationSession() async {
    _cancelAutoAdvance();
    await _recitationSession.stop();
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
  }

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return QuranStatusBar(
      dark: dark,
      child: Scaffold(
        backgroundColor: QuranTokens.background(dark),
        body: SafeArea(child: _buildBody(dark)),
      ),
    );
  }

  Widget _buildBody(bool dark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final surah = _surah;
    if (_error != null || surah == null) {
      return Center(
        child: Text(
          _error?.message ?? 'Terjadi kesalahan',
          style: QuranTokens.poppins(QuranTokens.tsSurahName)
              .copyWith(color: QuranTokens.secondaryColor(dark)),
        ),
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
        ValueListenableBuilder<MurojaahState>(
          valueListenable: _murojaah,
          builder: (context, state, _) {
            return _ProgressHeader(state: state, dark: dark);
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: MurojaahMushaf(
              surah: surah,
              controller: _murojaah,
              dark: dark,
            ),
          ),
        ),
        ValueListenableBuilder<MurojaahState>(
          valueListenable: _murojaah,
          builder: (context, state, _) {
            final active = state.activeVerse;
            final activeVerseTts = (active != null && active <= surah.verses.length)
                ? _ttsText(surah.verses[active - 1])
                : null;
            final isLongVerse = active != null && active <= surah.verses.length
                ? MurojaahController.isLongVerse(
                    surah.verses[active - 1]
                        .displayArabic(surah.number)
                        .trim()
                        .split(RegExp(r'\s+'))
                        .where((w) => w.isNotEmpty)
                        .length)
                : false;
            return _BottomControls(
              state: state,
              controller: _murojaah,
              speaker: _speaker,
              surahNumber: surah.number,
              totalVerses: surah.verses.length,
              activeVerseTts: activeVerseTts,
              isLongVerse: isLongVerse,
              onSubmit: _submitAccumulated,
              dark: dark,
              recitationSession: _recitationSession,
              onStartSession: _startRecitationSession,
              onStopSession: _stopRecitationSession,
            );
          },
        ),
      ],
    );
  }
}

/// Bilah progress (Milestone 3): ayat aktif + progress reveal.
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.state, required this.dark});

  final MurojaahState state;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final total = state.totalVerses ?? 0;
    final active = state.activeVerse;

    final Widget content;
    if (state.phase == MurojaahPhase.initial) {
      content = Row(
        children: [
          Icon(Icons.lock_outline,
              size: 18, color: QuranTokens.secondaryColor(dark)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Semua ayat tersembunyi — tekan Mulai Murojaah.',
              style: QuranTokens.poppins(QuranTokens.tsVerseNumber)
                  .copyWith(color: QuranTokens.inkColor(dark)),
            ),
          ),
        ],
      );
    } else {
      final value = total == 0 ? 0.0 : (state.revealedVerses / total).clamp(0.0, 1.0);
      final isDone = state.phase == MurojaahPhase.completed;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isDone ? 'Selesai' : 'Ayat ${active ?? total} / $total',
                style: QuranTokens.poppins(QuranTokens.tsSurahName)
                    .copyWith(color: QuranTokens.inkColor(dark)),
              ),
              Text(
                '${state.revealedVerses} / $total',
                style: QuranTokens.poppins(QuranTokens.tsVerseNumber)
                    .copyWith(color: QuranTokens.secondaryColor(dark)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: QuranTokens.divider(dark),
              color: isDone
                  ? QuranTokens.secondaryColor(dark)
                  : QuranTokens.brandColor(dark),
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: QuranTokens.surface(dark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: content,
    );
  }
}

/// Panel status & feedback validasi.
///
/// Menampilkan status sesi ASR dan akumulasi transkrip untuk ayat panjang.
class _SpeechPanel extends StatelessWidget {
  const _SpeechPanel({
    required this.state,
    required this.dark,
    this.accumulatedTranscript = '',
    this.sessionStatus,
  });

  final MurojaahState state;
  final bool dark;

  /// Akumulasi transkrip dari semua potongan rekaman pada ayat aktif.
  final String accumulatedTranscript;

  /// Status dari [MurojaahRecitationSession].
  final MurojaahSessionStatus? sessionStatus;

  @override
  Widget build(BuildContext context) {
    // Legacy matcher result takes priority when present.
    final matchResult = state.matchResult;
    // New-engine decision (murojaahDecision) checked when legacy matchResult is absent.
    final decision = state.murojaahDecision;

    final (icon, label, labelColor) = switch (matchResult) {
      MatchResult.accept => (
          Icons.check_circle,
          'Benar!',
          QuranTokens.brandColor(dark),
        ),
      MatchResult.almost => (
          Icons.refresh,
          'Hampir tepat. Coba lagi.',
          Colors.amber.shade700,
        ),
      MatchResult.reject => (
          Icons.refresh,
          'Belum tepat. Coba lagi.',
          QuranTokens.secondaryColor(dark),
        ),
      null => switch (decision) {
          MurojaahDecision.accept => (
              Icons.check_circle,
              'Benar!',
              QuranTokens.brandColor(dark),
            ),
          MurojaahDecision.retry || MurojaahDecision.reject => (
              Icons.refresh,
              'Belum tepat. Coba lagi.',
              QuranTokens.secondaryColor(dark),
            ),
          null => _sessionStatusLabel(dark),
        },
    };
    return _buildPanel(context, icon, label, labelColor);
  }

  /// Map [MurojaahSessionStatus] to (icon, label, color).
  (IconData, String, Color) _sessionStatusLabel(bool dark) {
    final ss = sessionStatus;
    if (ss != null) {
      return switch (ss) {
        MurojaahSessionStatus.idle => (
            Icons.mic_none,
            'Tekan Bicara lalu bacakan ayat aktif.',
            QuranTokens.inkColor(dark),
          ),
        MurojaahSessionStatus.initializing => (
            Icons.settings_input_antenna,
            'Menyiapkan mikrofon…',
            QuranTokens.inkColor(dark),
          ),
        MurojaahSessionStatus.listening => (
            Icons.graphic_eq,
            'Mendengarkan…',
            QuranTokens.inkColor(dark),
          ),
        MurojaahSessionStatus.processing => (
            Icons.hourglass_top,
            'Memproses rekaman…',
            QuranTokens.inkColor(dark),
          ),
        MurojaahSessionStatus.result => (
            Icons.check_circle_outline,
            'Hasil diterima.',
            QuranTokens.inkColor(dark),
          ),
        MurojaahSessionStatus.permissionDenied => (
            Icons.mic_off,
            'Izin mikrofon ditolak.',
            QuranTokens.secondaryColor(dark),
          ),
        MurojaahSessionStatus.error => (
            Icons.error_outline,
            'Terjadi kesalahan. Coba lagi.',
            QuranTokens.secondaryColor(dark),
          ),
      };
    }
    return (
      Icons.mic_none,
      'Tekan Bicara lalu bacakan ayat aktif.',
      QuranTokens.inkColor(dark),
    );
  }

  Widget _buildPanel(
      BuildContext context, IconData icon, String label, Color labelColor) {
    final matchResult = state.matchResult;
    final noFeedback = matchResult == null;
    final showAccumulated = noFeedback &&
        accumulatedTranscript.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: QuranTokens.verseBg(dark),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: labelColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: QuranTokens.poppins(QuranTokens.tsVerseNumber)
                      .copyWith(color: labelColor),
                ),
                // Akumulasi transkrip multi-rekam untuk ayat panjang
                if (showAccumulated) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.layers,
                        size: 12,
                        color: QuranTokens.secondaryColor(dark),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          accumulatedTranscript,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style:
                              QuranTokens.poppins(QuranTokens.tsVerseNumber)
                                  .copyWith(
                            color: QuranTokens.secondaryColor(dark),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel bantuan bacaan (M5+): tampil saat TTS membacakan ayat yang benar
/// setelah user 3 kali salah beruntun.
class _HelpPanel extends StatelessWidget {
  const _HelpPanel({required this.speaker, required this.dark});

  final VerseSpeakerSession speaker;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VerseSpeakerStatus>(
      valueListenable: speaker,
      builder: (context, status, _) {
        if (status != VerseSpeakerStatus.speaking) {
          return const SizedBox.shrink();
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: QuranTokens.verseBg(dark),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.volume_up, size: 18, color: QuranTokens.brandColor(dark)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Membacakan bacaan yang benar…',
                  style: QuranTokens.poppins(QuranTokens.tsVerseNumber)
                      .copyWith(color: QuranTokens.inkColor(dark)),
                ),
              ),
              IconButton(
                onPressed: speaker.stop,
                icon: Icon(Icons.stop_circle,
                    size: 20, color: QuranTokens.secondaryColor(dark)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Kontrol bawah: tombol Bicara/Berhenti + Dengar + Selesai + Ulang + bantuan bacaan TTS.
class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.state,
    required this.controller,
    required this.speaker,
    required this.surahNumber,
    required this.totalVerses,
    required this.dark,
    required this.onSubmit,
    required this.recitationSession,
    required this.isLongVerse,
    this.activeVerseTts,
    this.onStartSession,
    this.onStopSession,
  });

  final MurojaahState state;
  final MurojaahController controller;
  final VerseSpeakerSession speaker;
  final int surahNumber;
  final int totalVerses;
  final bool dark;

  /// Callback saat tombol "Selesai" ditekan — validasi akumulasi transkrip.
  final VoidCallback onSubmit;

  /// Teks transliterasi Latin ayat aktif untuk diputar TTS saat tombol "Dengar"
  /// ditekan. Null bila tidak ada ayat aktif atau transliteration belum tersedia.
  final String? activeVerseTts;

  /// True bila ayat aktif termasuk ayat panjang (≥ longVerseWordThreshold kata).
  /// Hanya ayat panjang yang menampilkan tombol "Selesai" (multi-rekam).
  final bool isLongVerse;

  /// ASR session — owned by MurojaahPageShell, always non-null.
  final MurojaahRecitationSession recitationSession;

  /// Start the recitation session for the current active verse.
  final Future<void> Function()? onStartSession;

  /// Stop the recitation session.
  final Future<void> Function()? onStopSession;

  void _start() {
    speaker.stop();
    controller.start(surahNumber: surahNumber, totalVerses: totalVerses);
    onStartSession?.call();
  }

  void _listenCorrect() {
    final text = activeVerseTts;
    if (text == null || text.isEmpty) return;
    controller.clearFeedback();
    speaker.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final running = state.phase == MurojaahPhase.running;
    return ListenableBuilder(
      listenable: recitationSession,
      builder: (context, _) {
        final sessionStatus = recitationSession.state.status;
        final busy = sessionStatus == MurojaahSessionStatus.initializing ||
            sessionStatus == MurojaahSessionStatus.listening ||
            sessionStatus == MurojaahSessionStatus.processing;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (running)
                  _SpeechPanel(
                    state: state,
                    dark: dark,
                    accumulatedTranscript: controller.accumulatedTranscript,
                    sessionStatus: sessionStatus,
                  ),
                if (running) _HelpPanel(speaker: speaker, dark: dark),
                switch (state.phase) {
                  MurojaahPhase.initial => FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Mulai Murojaah'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: QuranTokens.brandColor(dark),
                      ),
                    ),
                  MurojaahPhase.running => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tombol Bicara / Berhenti
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: busy
                                ? () => onStopSession?.call()
                                : () {
                                    controller.clearFeedback();
                                    speaker.stop();
                                    onStartSession?.call();
                                  },
                            icon: Icon(busy ? Icons.mic_off : Icons.mic),
                            label: Text(busy ? 'Berhenti' : 'Bicara'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: QuranTokens.brandColor(dark),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Tombol Dengar — putar TTS bacaan ayat aktif
                        ValueListenableBuilder<VerseSpeakerStatus>(
                          valueListenable: speaker,
                          builder: (context, speakerStatus, _) {
                            final isSpeaking =
                                speakerStatus == VerseSpeakerStatus.speaking;
                            return OutlinedButton.icon(
                              onPressed: isSpeaking
                                  ? speaker.stop
                                  : (activeVerseTts != null && activeVerseTts!.isNotEmpty
                                      ? _listenCorrect
                                      : null),
                              icon: Icon(
                                isSpeaking ? Icons.stop : Icons.volume_up,
                              ),
                              label: Text(isSpeaking ? 'Stop' : 'Dengar'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                foregroundColor: QuranTokens.brandColor(dark),
                                side: BorderSide(
                                  color: isSpeaking
                                      ? QuranTokens.brandColor(dark)
                                      : QuranTokens.divider(dark),
                                ),
                              ),
                            );
                          },
                        ),
                        // Tombol Selesai — hanya untuk ayat panjang (multi-rekam)
                        if (isLongVerse) ...[
                          const SizedBox(height: 8),
                          ValueListenableBuilder<String>(
                            valueListenable: _AccumulatedNotifier(controller),
                            builder: (context, accumulated, _) {
                              final hasAccumulated =
                                  accumulated.trim().isNotEmpty;
                              return FilledButton.icon(
                                onPressed: hasAccumulated && !busy
                                    ? onSubmit
                                    : null,
                                icon: const Icon(Icons.done_all),
                                label: const Text('Selesai'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  backgroundColor: hasAccumulated && !busy
                                      ? QuranTokens.brandColor(dark)
                                          .withValues(alpha: 0.85)
                                      : QuranTokens.divider(dark),
                                  foregroundColor: hasAccumulated && !busy
                                      ? Colors.white
                                      : QuranTokens.secondaryColor(dark),
                                ),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _start,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Ulang'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: QuranTokens.secondaryColor(dark),
                            side: BorderSide(color: QuranTokens.divider(dark)),
                          ),
                        ),
                      ],
                    ),
                  MurojaahPhase.completed => FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.replay),
                      label: const Text('Mulai Ulang'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: QuranTokens.brandColor(dark),
                      ),
                    ),
                },
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ValueNotifier tipis yang expose [MurojaahController.accumulatedTranscript]
/// agar [_BottomControls] bisa rebuild tombol "Selesai" reaktif.
class _AccumulatedNotifier extends ValueNotifier<String> {
  _AccumulatedNotifier(this._controller)
      : super(_controller.accumulatedTranscript) {
    _controller.addListener(_onChanged);
  }

  final MurojaahController _controller;

  void _onChanged() {
    value = _controller.accumulatedTranscript;
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }
}
