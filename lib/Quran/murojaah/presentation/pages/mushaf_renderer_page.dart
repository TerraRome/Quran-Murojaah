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

/// Teks Bismillah standar yang ditampilkan di header surah.
/// Surah At-Taubah (9) tidak diawali Bismillah.
const _kBismillah = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

/// Halaman renderer mushaf Murojaah (E7 UI/UX redesign).
///
/// Layout: surah identity header → Quran verses → circular mic primary action.
/// Microphone adalah primary action. Ayat adalah konten utama.
/// User "menyetorkan hafalan", bukan mengoperasikan voice recorder.
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
    final verse = surah.verses[active - 1];

    final accepted = _murojaah.validateWithMatcher(
      transcript: transcript,
      expectedArabic: verse.displayArabic(surah.number),
      surahNumber: surah.number,
      totalVerses: surah.verses.length,
    );

    if (accepted) {
      // E6: flag pending auto-advance; timer armed in SessionStopped handler.
      _pendingAutoAdvance = true;
    } else {
      // REJECT: trigger TTS help after helpThreshold consecutive misses.
      if (_murojaah.shouldTriggerHelp) {
        final verse = surah.verses[active - 1];
        _speaker.speak(_ttsText(verse));
      }
    }
  }

  /// E6: Called when the 800 ms delay has elapsed after ACCEPT.
  /// Restarts the session for the next verse unless TTS is speaking.
  void _onAutoAdvanceTimer() {
    if (!mounted) return;
    if (_murojaah.value.phase != MurojaahPhase.running) return;
    if (_speaker.value == VerseSpeakerStatus.speaking) {
      // TTS is still reading — defer restart until TTS finishes.
      _ttsBlockedAutoRestart = true;
      return;
    }
    _startRecitationSession();
  }

  /// Called when the TTS speaker state changes.
  /// If a deferred auto-restart is pending and TTS just finished, restart now.
  void _onSpeakerChanged() {
    if (!mounted) return;

    // If TTS blocked the auto-restart and just finished, start the session.
    if (_ttsBlockedAutoRestart &&
        _speaker.value != VerseSpeakerStatus.speaking) {
      _ttsBlockedAutoRestart = false;
      _startRecitationSession();
      return;
    }

    // If TTS just started (help), stop the active session to release mic.
    if (_speaker.value == VerseSpeakerStatus.speaking) {
      _recitationSession.stop();
    }
  }

  /// Called on every [MurojaahController] state change.
  /// Stops the session when murojaah completes all verses.
  void _onMurojaahChanged() {
    if (!mounted) return;
    if (_murojaah.value.phase == MurojaahPhase.completed) {
      _cancelAutoAdvance();
      _recitationSession.stop();
    }
    setState(() {});
  }

  /// Validate the accumulated transcript for the active verse (long-verse
  /// manual submit path). Called from the long-verse "Selesai" action.
  void _submitAccumulated() {
    if (!_murojaah.value.isRunning) return;
    final surah = _surah;
    if (surah == null) return;
    final active = _murojaah.value.activeVerse;
    if (active == null) return;

    final verse = surah.verses[active - 1];
    final accepted = _murojaah.validate(
      transcript: _murojaah.accumulatedTranscript,
      expectedArabic: verse.displayArabic(surah.number),
      verseNormalized: verse.normalizedText,
      surahNumber: surah.number,
      totalVerses: surah.verses.length,
    );

    if (accepted) {
      _pendingAutoAdvance = true;
      _recitationSession.stop();
    } else if (_murojaah.shouldTriggerHelp) {
      final verse = surah.verses[active - 1];
      _speaker.speak(_ttsText(verse));
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
  /// Called when "Mulai Murojaah" / "Ulang" starts a fresh run, or when
  /// E6 auto-advance timer fires.
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
        const SizedBox(height: 4),
        // Back button row — minimal, tidak mengambil ruang
        _TopBar(
          surah: surah,
          dark: dark,
          onBack: () => context.pop(),
          onThemeToggle: () => QuranThemeScope.toggleDark(context),
        ),
        // Surah identity header: nama + bismillah
        _SurahHeader(surah: surah, dark: dark),
        // Quran text — dominant area
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
        // Bottom controls: mic primary + secondary flanking
        ValueListenableBuilder<MurojaahState>(
          valueListenable: _murojaah,
          builder: (context, state, _) {
            final active = state.activeVerse;
            final activeVerseTts =
                (active != null && active <= surah.verses.length)
                    ? _ttsText(surah.verses[active - 1])
                    : null;
            final isLongVerse =
                active != null && active <= surah.verses.length
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

// ─────────────────────────────────────────────────────────────────────────────
// _TopBar — minimal back + theme toggle, tidak mengambil terlalu banyak ruang
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.surah,
    required this.dark,
    required this.onBack,
    required this.onThemeToggle,
  });

  final Surah surah;
  final bool dark;
  final VoidCallback onBack;
  final VoidCallback onThemeToggle;

  @override
  Widget build(BuildContext context) {
    return QuranTopBar(
      title: surah.transliteration,
      titleColor: QuranTokens.brandColor(dark),
      leading: IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        color: QuranTokens.inkColor(dark),
      ),
      onThemeToggle: onThemeToggle,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SurahHeader — Ornamental header: nama latin + bismillah (E7)
// Menggantikan _ProgressHeader yang menampilkan "Ayat X/Y" dan progress bar.
// ─────────────────────────────────────────────────────────────────────────────

class _SurahHeader extends StatelessWidget {
  const _SurahHeader({required this.surah, required this.dark});

  final Surah surah;
  final bool dark;

  /// Surah At-Taubah (9) tidak diawali Bismillah.
  bool get _showBismillah => surah.number != 9;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 2, 24, 8),
      child: Column(
        children: [
          if (_showBismillah)
            Text(
              _kBismillah,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: QuranTokens.amiri(
                TextStyle(
                  fontSize: 16,
                  color: QuranTokens.secondaryColor(dark),
                  height: 1.8,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FeedbackChip — subtle feedback overlay, tidak menggeser layout
// ─────────────────────────────────────────────────────────────────────────────

class _FeedbackChip extends StatelessWidget {
  const _FeedbackChip({
    required this.state,
    required this.dark,
    required this.sessionStatus,
  });

  final MurojaahState state;
  final bool dark;
  final MurojaahSessionStatus? sessionStatus;

  @override
  Widget build(BuildContext context) {
    final matchResult = state.matchResult;
    final decision = state.murojaahDecision;

    // Resolve feedback label + color
    final (String label, Color color, IconData icon) = switch (matchResult) {
      MatchResult.accept => ('Benar!', QuranTokens.brandColor(dark), Icons.check_circle_outline),
      MatchResult.almost => (
          'Hampir tepat.',
          Colors.amber.shade700,
          Icons.refresh,
        ),
      MatchResult.reject => (
          'Belum tepat.',
          QuranTokens.secondaryColor(dark),
          Icons.refresh,
        ),
      null => switch (decision) {
          MurojaahDecision.accept => (
              'Benar!',
              QuranTokens.brandColor(dark),
              Icons.check_circle_outline,
            ),
          MurojaahDecision.retry || MurojaahDecision.reject => (
              'Belum tepat.',
              QuranTokens.secondaryColor(dark),
              Icons.refresh,
            ),
          null => _fromSessionStatus(),
        },
    };

    // When there is no actionable feedback and no active status, hide.
    if (label.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: QuranTokens.poppins(
              TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, IconData) _fromSessionStatus() {
    final ss = sessionStatus;
    if (ss == null) return ('', QuranTokens.inkColor(dark), Icons.mic_none);
    return switch (ss) {
      MurojaahSessionStatus.idle => (
          '',
          QuranTokens.inkColor(dark),
          Icons.mic_none,
        ),
      MurojaahSessionStatus.initializing => (
          'Menyiapkan mikrofon…',
          QuranTokens.inkColor(dark),
          Icons.settings_input_antenna,
        ),
      MurojaahSessionStatus.listening => (
          'Mendengarkan…',
          QuranTokens.brandColor(dark),
          Icons.graphic_eq,
        ),
      MurojaahSessionStatus.processing => (
          'Memproses…',
          QuranTokens.secondaryColor(dark),
          Icons.hourglass_top,
        ),
      MurojaahSessionStatus.result => (
          '',
          QuranTokens.inkColor(dark),
          Icons.mic_none,
        ),
      MurojaahSessionStatus.error => (
          'Terjadi kesalahan. Coba lagi.',
          Colors.red.shade400,
          Icons.error_outline,
        ),
      MurojaahSessionStatus.permissionDenied => (
          'Izin mikrofon ditolak.',
          Colors.red.shade400,
          Icons.mic_off,
        ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HelpPanel — TTS sedang membacakan ayat yang benar
// ─────────────────────────────────────────────────────────────────────────────

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
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.volume_up, size: 14, color: QuranTokens.brandColor(dark)),
              const SizedBox(width: 4),
              Text(
                'Membacakan bacaan yang benar…',
                style: QuranTokens.poppins(
                  TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: QuranTokens.inkColor(dark),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: speaker.stop,
                child: Icon(
                  Icons.stop_circle,
                  size: 14,
                  color: QuranTokens.secondaryColor(dark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MicButton — circular primary mic button dengan pulse state saat listening
// ─────────────────────────────────────────────────────────────────────────────

class _MicButton extends StatefulWidget {
  const _MicButton({
    required this.sessionStatus,
    required this.dark,
    required this.onTap,
  });

  final MurojaahSessionStatus sessionStatus;
  final bool dark;
  final VoidCallback onTap;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(_MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionStatus != widget.sessionStatus) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.sessionStatus == MurojaahSessionStatus.listening) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listening = widget.sessionStatus == MurojaahSessionStatus.listening;
    final processing = widget.sessionStatus == MurojaahSessionStatus.processing ||
        widget.sessionStatus == MurojaahSessionStatus.initializing;

    final brandColor = QuranTokens.brandColor(widget.dark);

    return Semantics(
      label: listening ? 'Berhenti merekam' : 'Mulai merekam',
      button: true,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: listening ? _scale.value : 1.0,
            child: child,
          );
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: listening
                  ? brandColor
                  : processing
                      ? brandColor.withValues(alpha: 0.6)
                      : brandColor,
              boxShadow: [
                BoxShadow(
                  color: brandColor.withValues(alpha: listening ? 0.4 : 0.2),
                  blurRadius: listening ? 20 : 10,
                  spreadRadius: listening ? 4 : 1,
                ),
              ],
            ),
            child: Center(
              child: processing
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    )
                  : Icon(
                      listening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 30,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BottomControls — E7 redesign
//
// Layout:
//   [feedback chip + help panel]
//   [Ulang]   [🎙 Mic]   [Dengar]
//
// initial phase  → "Mulai Murojaah" full-width CTA
// running phase  → circular mic + flanking secondary buttons
// completed phase → clean completion state
// ─────────────────────────────────────────────────────────────────────────────

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

  /// Callback saat tombol "Selesai" ditekan untuk ayat panjang.
  final VoidCallback onSubmit;

  /// Teks TTS ayat aktif. Null bila tidak tersedia.
  final String? activeVerseTts;

  /// True bila ayat aktif termasuk ayat panjang (≥ longVerseWordThreshold kata).
  final bool isLongVerse;

  /// ASR session — owned by MurojaahPageShell.
  final MurojaahRecitationSession recitationSession;

  final Future<void> Function()? onStartSession;
  final Future<void> Function()? onStopSession;

  /// Restart murojaah dari awal.
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: switch (state.phase) {
              // ── Initial: single full-width CTA ──────────────────────────────
              MurojaahPhase.initial => _buildInitialPhase(),

              // ── Running: circular mic + flanking secondary ───────────────────
              MurojaahPhase.running => _buildRunningPhase(
                  sessionStatus: sessionStatus,
                  busy: busy,
                  context: context,
                ),

              // ── Completed: clean completion state ────────────────────────────
              MurojaahPhase.completed => _buildCompletedPhase(),
            },
          ),
        );
      },
    );
  }

  Widget _buildInitialPhase() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Mulai Murojaah'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: QuranTokens.brandColor(dark),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRunningPhase({
    required MurojaahSessionStatus sessionStatus,
    required bool busy,
    required BuildContext context,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Subtle feedback chip (Benar! / Belum tepat. / status)
        _FeedbackChip(
          state: state,
          dark: dark,
          sessionStatus: sessionStatus,
        ),
        // TTS help notification
        _HelpPanel(speaker: speaker, dark: dark),
        // Main controls row: [Ulang] [🎙] [Dengar]
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Ulang (secondary left) ──────────────────────────────────────
            _SecondaryButton(
              icon: Icons.refresh,
              label: 'Ulang',
              dark: dark,
              onTap: _start,
            ),
            const SizedBox(width: 24),
            // ── Microphone (primary center) ─────────────────────────────────
            _MicButton(
              sessionStatus: sessionStatus,
              dark: dark,
              onTap: busy
                  ? () => onStopSession?.call()
                  : () {
                      controller.clearFeedback();
                      speaker.stop();
                      onStartSession?.call();
                    },
            ),
            const SizedBox(width: 24),
            // ── Dengar (secondary right) ────────────────────────────────────
            ValueListenableBuilder<VerseSpeakerStatus>(
              valueListenable: speaker,
              builder: (context, speakerStatus, _) {
                final isSpeaking = speakerStatus == VerseSpeakerStatus.speaking;
                return _SecondaryButton(
                  icon: isSpeaking ? Icons.stop : Icons.volume_up,
                  label: isSpeaking ? 'Stop' : 'Dengar',
                  dark: dark,
                  onTap: isSpeaking
                      ? speaker.stop
                      : (activeVerseTts != null && activeVerseTts!.isNotEmpty
                          ? _listenCorrect
                          : null),
                  active: isSpeaking,
                );
              },
            ),
          ],
        ),
        // Long-verse Selesai — small, non-intrusive, only when has accumulated
        if (isLongVerse)
          ValueListenableBuilder<String>(
            valueListenable: _AccumulatedNotifier(controller),
            builder: (context, accumulated, _) {
              final hasAccumulated = accumulated.trim().isNotEmpty;
              if (!hasAccumulated) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextButton.icon(
                  onPressed: busy ? null : onSubmit,
                  icon: Icon(
                    Icons.done_all,
                    size: 16,
                    color: busy
                        ? QuranTokens.secondaryColor(dark)
                        : QuranTokens.brandColor(dark),
                  ),
                  label: Text(
                    'Selesai rekam',
                    style: QuranTokens.poppins(
                      TextStyle(
                        fontSize: 13,
                        color: busy
                            ? QuranTokens.secondaryColor(dark)
                            : QuranTokens.brandColor(dark),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCompletedPhase() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle,
          size: 40,
          color: QuranTokens.brandColor(dark),
        ),
        const SizedBox(height: 6),
        Text(
          'Murojaah selesai',
          style: QuranTokens.poppins(
            TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: QuranTokens.inkColor(dark),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.replay),
          label: const Text('Ulangi'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: QuranTokens.brandColor(dark),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SecondaryButton — flanking icon + label button
// ─────────────────────────────────────────────────────────────────────────────

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.dark,
    this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool dark;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? QuranTokens.brandColor(dark)
        : onTap != null
            ? QuranTokens.secondaryColor(dark)
            : QuranTokens.secondaryColor(dark).withValues(alpha: 0.4);

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: QuranTokens.poppins(
                  TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AccumulatedNotifier — reactive listener untuk akumulasi transkrip ayat panjang
// ─────────────────────────────────────────────────────────────────────────────

/// ValueNotifier tipis yang expose [MurojaahController.accumulatedTranscript]
/// agar long-verse Selesai button bisa rebuild secara reaktif.
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
