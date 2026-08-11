/// recitation_session_event.dart
///
/// Sealed class hierarchy of events emitted by [MurojaahRecitationSession].
///
/// Events are published on [MurojaahRecitationSession.events] stream.
/// They represent important session lifecycle transitions and are lightweight
/// (no large PCM buffers in the event payload — use session state for that).
import '../domain/murojaah_match_result.dart';
import '../infrastructure/asr/quran_asr_result.dart';

export '../domain/murojaah_match_result.dart' show MurojaahDecision, MurojaahMatchResult;
export '../infrastructure/asr/quran_asr_result.dart' show AsrInferenceResult;

// ---------------------------------------------------------------------------
// Base class
// ---------------------------------------------------------------------------

/// Base class for all [MurojaahRecitationSession] events.
sealed class RecitationSessionEvent {
  const RecitationSessionEvent();
}

// ---------------------------------------------------------------------------
// Lifecycle events
// ---------------------------------------------------------------------------

/// Session started successfully. Recorder is active.
final class SessionStarted extends RecitationSessionEvent {
  const SessionStarted();
}

/// Session stopped (either by caller or after ACCEPT).
final class SessionStopped extends RecitationSessionEvent {
  const SessionStopped();
}

// ---------------------------------------------------------------------------
// Audio / VAD events
// ---------------------------------------------------------------------------

/// VAD detected speech onset — the segmenter transitioned to SPEAKING.
final class SpeechStarted extends RecitationSessionEvent {
  const SpeechStarted();
}

/// VAD detected speech end — the segmenter finalized an utterance.
final class SpeechEnded extends RecitationSessionEvent {
  const SpeechEnded({required this.utteranceDurationSeconds});

  /// Duration of the finalized utterance in seconds.
  final double utteranceDurationSeconds;
}

/// An utterance was finalized and is ready for ASR.
final class UtteranceReady extends RecitationSessionEvent {
  const UtteranceReady({required this.utteranceIndex});

  /// 1-based index of this utterance within the session.
  final int utteranceIndex;
}

/// A second utterance arrived while ASR was busy. It was queued.
final class UtteranceQueued extends RecitationSessionEvent {
  const UtteranceQueued({required this.queueLength});

  /// Number of utterances currently waiting in the queue.
  final int queueLength;
}

// ---------------------------------------------------------------------------
// ASR / matching events
// ---------------------------------------------------------------------------

/// ASR inference started for an utterance.
final class ProcessingStarted extends RecitationSessionEvent {
  const ProcessingStarted({required this.utteranceIndex});

  /// 1-based index of the utterance being processed.
  final int utteranceIndex;
}

/// ASR inference completed.
final class TranscriptionCompleted extends RecitationSessionEvent {
  const TranscriptionCompleted({
    required this.transcript,
    required this.asrResult,
  });

  /// The decoded Arabic transcript.
  final String transcript;

  /// Full ASR result including timing.
  final AsrInferenceResult asrResult;
}

/// Matching completed. Contains the final decision.
final class MatchingCompleted extends RecitationSessionEvent {
  const MatchingCompleted({required this.matchResult});

  /// Full match result including decision, score, and alignment.
  final MurojaahMatchResult matchResult;
}

// ---------------------------------------------------------------------------
// Error events
// ---------------------------------------------------------------------------

/// An error occurred in the session.
final class SessionError extends RecitationSessionEvent {
  const SessionError({required this.message, this.cause});

  /// Human-readable error description.
  final String message;

  /// The underlying exception, if available.
  final Object? cause;
}
