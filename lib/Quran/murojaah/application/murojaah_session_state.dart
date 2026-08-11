/// murojaah_session_state.dart
///
/// Immutable state object for [MurojaahRecitationSession].
///
/// This is the session-local state only — it tracks the live audio capture
/// and ASR pipeline. It does NOT duplicate [MurojaahController] state (verse
/// progression, revealed verses, etc.).
import '../infrastructure/asr/quran_asr_result.dart';
import '../domain/murojaah_match_result.dart';
import '../infrastructure/audio/murojaah_audio_buffer.dart';

export '../domain/murojaah_match_result.dart' show MurojaahDecision, MurojaahMatchResult;
export '../infrastructure/asr/quran_asr_result.dart' show AsrInferenceResult;

// ---------------------------------------------------------------------------
// Status enum
// ---------------------------------------------------------------------------

/// Live status of [MurojaahRecitationSession].
enum MurojaahSessionStatus {
  /// Session is not active. No recorder running.
  idle,

  /// Session is initializing: requesting permission, preparing recorder.
  initializing,

  /// Recorder is active, VAD is processing frames. Waiting for speech.
  listening,

  /// An utterance was finalized. ASR inference is running.
  processing,

  /// ASR + matching completed for the latest utterance.
  /// The session returned to listening if decision was reject/retry,
  /// or stopped if decision was accept.
  result,

  /// Microphone permission was denied.
  permissionDenied,

  /// An unrecoverable error occurred. Call [MurojaahRecitationSession.stop]
  /// then [MurojaahRecitationSession.start] to retry.
  error,
}

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

/// Configuration for a single recitation session.
class MurojaahSessionConfig {
  const MurojaahSessionConfig({
    required this.expectedArabic,
    this.threshold = 0.80,
  });

  /// The expected Arabic verse text that the user should recite.
  final String expectedArabic;

  /// Matching acceptance threshold. Defaults to 0.80 (validated POC value).
  final double threshold;
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable snapshot of [MurojaahRecitationSession] at a point in time.
class MurojaahSessionState {
  const MurojaahSessionState({
    required this.status,
    this.currentRms = 0.0,
    this.currentPeak = 0.0,
    this.isSpeechDetected = false,
    this.currentUtteranceDurationSeconds = 0.0,
    this.completedUtteranceCount = 0,
    this.lastBuffer,
    this.lastAsrResult,
    this.lastMatchResult,
    this.errorMessage,
  });

  /// Current session status.
  final MurojaahSessionStatus status;

  // ── Live audio diagnostics (updated during listening/speaking) ──────────

  /// RMS amplitude of the most recent VAD frame (0.0–1.0).
  final double currentRms;

  /// Peak amplitude of the most recent VAD frame (0.0–1.0).
  final double currentPeak;

  /// Whether the most recent VAD frame was classified as speech.
  final bool isSpeechDetected;

  /// Duration in seconds of the utterance currently accumulating.
  /// 0.0 when not in speaking state.
  final double currentUtteranceDurationSeconds;

  // ── Utterance / ASR history ──────────────────────────────────────────────

  /// Number of utterances fully processed (ASR completed) in this session.
  final int completedUtteranceCount;

  /// The last finalized [MurojaahAudioBuffer], available after an utterance
  /// is finalized. Useful for diagnostics.
  final MurojaahAudioBuffer? lastBuffer;

  /// The last [AsrInferenceResult], populated after ASR completes.
  final AsrInferenceResult? lastAsrResult;

  /// The last [MurojaahMatchResult], populated after matching completes.
  final MurojaahMatchResult? lastMatchResult;

  // ── Error ────────────────────────────────────────────────────────────────

  /// Human-readable error message. Non-null when [status] is
  /// [MurojaahSessionStatus.error] or [MurojaahSessionStatus.permissionDenied].
  final String? errorMessage;

  // ── Convenience getters ──────────────────────────────────────────────────

  bool get isIdle           => status == MurojaahSessionStatus.idle;
  bool get isInitializing   => status == MurojaahSessionStatus.initializing;
  bool get isListening      => status == MurojaahSessionStatus.listening;
  bool get isProcessing     => status == MurojaahSessionStatus.processing;
  bool get isResult         => status == MurojaahSessionStatus.result;
  bool get isPermissionDenied => status == MurojaahSessionStatus.permissionDenied;
  bool get isError          => status == MurojaahSessionStatus.error;

  /// Last transcript string, or null if no ASR result yet.
  String? get lastTranscript => lastAsrResult?.transcript;

  /// Last decision, or null if no match result yet.
  MurojaahDecision? get lastDecision => lastMatchResult?.decision;

  /// Last effective score, or null if no match result yet.
  double? get lastScore => lastMatchResult?.effectiveScore;

  // ── copyWith ─────────────────────────────────────────────────────────────

  MurojaahSessionState copyWith({
    MurojaahSessionStatus? status,
    double? currentRms,
    double? currentPeak,
    bool? isSpeechDetected,
    double? currentUtteranceDurationSeconds,
    int? completedUtteranceCount,
    MurojaahAudioBuffer? lastBuffer,
    AsrInferenceResult? lastAsrResult,
    MurojaahMatchResult? lastMatchResult,
    String? errorMessage,
    bool clearError = false,
    bool clearLastBuffer = false,
    bool clearLastResult = false,
  }) {
    return MurojaahSessionState(
      status: status ?? this.status,
      currentRms: currentRms ?? this.currentRms,
      currentPeak: currentPeak ?? this.currentPeak,
      isSpeechDetected: isSpeechDetected ?? this.isSpeechDetected,
      currentUtteranceDurationSeconds:
          currentUtteranceDurationSeconds ?? this.currentUtteranceDurationSeconds,
      completedUtteranceCount: completedUtteranceCount ?? this.completedUtteranceCount,
      lastBuffer: clearLastBuffer ? null : (lastBuffer ?? this.lastBuffer),
      lastAsrResult: clearLastResult ? null : (lastAsrResult ?? this.lastAsrResult),
      lastMatchResult: clearLastResult ? null : (lastMatchResult ?? this.lastMatchResult),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  // ── Named constructors ───────────────────────────────────────────────────

  const MurojaahSessionState.idle()
      : this(status: MurojaahSessionStatus.idle);

  @override
  String toString() =>
      'MurojaahSessionState('
      'status=$status '
      'rms=${currentRms.toStringAsFixed(3)} '
      'utterances=$completedUtteranceCount'
      '${errorMessage != null ? " error=$errorMessage" : ""}'
      ')';
}
