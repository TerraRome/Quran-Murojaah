/// murojaah_recitation_session.dart
///
/// Application-layer orchestrator for the Murojaah automatic recitation
/// pipeline.
///
/// Pipeline:
///   MurojaahAudioRecorder (streaming PCM bytes)
///     → MurojaahUtteranceSegmenter (VAD / boundary detection)
///     → QuranAsrEngine.transcribeSamples()
///     → MurojaahMatcher.match()
///     → MurojaahSessionState + RecitationSessionEvent
///
/// Responsibilities:
///   - Recorder lifecycle (start / stop / dispose)
///   - PCM stream consumption and segmenter feeding
///   - ASR concurrency guard (serialized queue, one inference at a time)
///   - Matcher invocation
///   - Session state machine
///   - Event emission
///
/// NOT responsible for:
///   - Verse progression (MurojaahController)
///   - VAD algorithm (MurojaahUtteranceSegmenter / EnergyVad)
///   - ONNX implementation (QuranOnnxRecognizer)
///   - UI
import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../domain/murojaah_matcher.dart';
import '../infrastructure/asr/quran_onnx_model.dart';
import '../infrastructure/audio/murojaah_audio_recorder.dart';
import '../infrastructure/audio/murojaah_utterance_segmenter.dart';
import 'murojaah_session_state.dart';
import 'recitation_session_event.dart';

export 'murojaah_session_state.dart';
export 'recitation_session_event.dart';

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------

/// Orchestrates the full mic → VAD → ASR → match pipeline for one verse.
///
/// Usage:
/// ```dart
/// final session = MurojaahRecitationSession(
///   recorder:   myRecorder,
///   segmenter:  MurojaahUtteranceSegmenter(),
///   asrEngine:  QuranOnnxRecognizer(),
/// );
///
/// await session.start(MurojaahSessionConfig(expectedArabic: verse));
///
/// // Observe state / events
/// session.addListener(() { ... session.state ... });
/// session.events.listen((event) { ... });
///
/// await session.stop();
/// session.dispose();
/// ```
class MurojaahRecitationSession extends ChangeNotifier {
  MurojaahRecitationSession({
    required MurojaahAudioRecorder recorder,
    required MurojaahUtteranceSegmenter segmenter,
    required QuranAsrEngine asrEngine,
  })  : _recorder = recorder,
        _segmenter = segmenter,
        _asrEngine = asrEngine;

  // ── Dependencies ──────────────────────────────────────────────────────────

  final MurojaahAudioRecorder _recorder;
  final MurojaahUtteranceSegmenter _segmenter;
  final QuranAsrEngine _asrEngine;

  // ── State ─────────────────────────────────────────────────────────────────

  MurojaahSessionState _state = const MurojaahSessionState.idle();

  /// Current immutable session state.
  MurojaahSessionState get state => _state;

  // ── Events ────────────────────────────────────────────────────────────────

  final StreamController<RecitationSessionEvent> _eventController =
      StreamController<RecitationSessionEvent>.broadcast();

  /// Stream of [RecitationSessionEvent]s emitted during the session.
  Stream<RecitationSessionEvent> get events => _eventController.stream;

  // ── Lifecycle flags ───────────────────────────────────────────────────────

  bool _disposed = false;
  bool _started = false;
  MurojaahSessionConfig? _config;

  // ── Recorder stream subscription ─────────────────────────────────────────

  StreamSubscription<Uint8List>? _audioSub;

  // ── ASR serialization queue ───────────────────────────────────────────────

  /// Queue of finalized utterances waiting for ASR. Bounded to avoid
  /// unbounded memory growth — oldest entry is dropped if the queue
  /// exceeds [_maxQueueDepth].
  final Queue<MurojaahAudioBuffer> _utteranceQueue = Queue();
  static const int _maxQueueDepth = 3;

  bool _asrRunning = false;

  /// 1-based count of utterances submitted to ASR this session.
  int _utteranceIndex = 0;

  // ── Diagnostics counter ───────────────────────────────────────────────────

  int _completedUtteranceCount = 0;

  // ── Onset deduplication (E4) ─────────────────────────────────────────────

  /// Tracks the previous segmenter state to detect idle→speaking transitions.
  /// Initialized to idle; updated every audio chunk.
  SegmenterState _prevSegmenterState = SegmenterState.idle;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Pre-warm the ASR engine to eliminate first-inference model-load latency.
  ///
  /// Must be called after construction and before [start]. Safe to call
  /// concurrently — the engine guards against redundant loads.
  ///
  /// Never throws: failures are logged and the lazy-load fallback remains
  /// active. The session is still fully usable if warm-up fails.
  ///
  /// Does NOT start the microphone or change session status.
  Future<void> warmUp() async {
    if (_disposed) return;
    try {
      await _asrEngine.warmUp();
      debugPrint('[Session] ASR warm-up complete.');
    } catch (e) {
      debugPrint('[Session] ASR warm-up failed (non-fatal): $e');
    }
  }

  /// Start the session for [config.expectedArabic].
  ///
  /// Requests microphone permission, initializes the recorder, starts
  /// streaming PCM into the segmenter.
  ///
  /// Throws [StateError] if called after [dispose].
  Future<void> start(MurojaahSessionConfig config) async {
    _assertNotDisposed();
    if (_started) {
      debugPrint('[Session] start() called while already started — ignoring');
      return;
    }

    _config = config;
    debugPrint(
      '[Session] start() — expected="${config.expectedArabic.substring(0, config.expectedArabic.length.clamp(0, 30))}…"',
    );

    _setState(_state.copyWith(status: MurojaahSessionStatus.initializing));

    // Permission check
    bool granted = false;
    try {
      granted = await _recorder.requestPermission();
    } catch (e) {
      _handleError('Permission request failed', e);
      return;
    }

    if (!granted) {
      debugPrint('[Session] Microphone permission denied.');
      _setState(_state.copyWith(
        status: MurojaahSessionStatus.permissionDenied,
        errorMessage: 'Microphone permission denied',
      ));
      _emitEvent(const SessionError(message: 'Microphone permission denied'));
      return;
    }

    // Initialize recorder
    try {
      await _recorder.initialize();
    } catch (e) {
      _handleError('Recorder initialization failed', e);
      return;
    }

    // Reset segmenter for a fresh session
    _segmenter.reset();

    // Start streaming recorder
    try {
      await _recorder.start();
    } catch (e) {
      _handleError('Recorder start failed', e);
      return;
    }

    // Subscribe to PCM stream
    if (_recorder is StreamingAudioRecorder) {
      _audioSub = _recorder.audioStream.listen(
        _onAudioChunk,
        onError: (Object e) => _handleError('Audio stream error', e),
        cancelOnError: false,
      );
    } else {
      // Non-streaming recorder: session cannot function as a streaming pipeline.
      // This is a programming error — the caller must provide a streaming recorder.
      _handleError(
        'Recorder does not implement StreamingAudioRecorder. '
        'MurojaahRecitationSession requires a streaming recorder.',
        null,
      );
      return;
    }

    _started = true;
    _setState(_state.copyWith(
      status: MurojaahSessionStatus.listening,
      clearError: true,
    ));
    _emitEvent(const SessionStarted());
    debugPrint('[Session] Listening started.');
  }

  /// Stop the session cleanly.
  ///
  /// Stops the recorder and cancels the audio stream subscription.
  /// Any in-flight ASR inference completes but its result is discarded.
  /// Safe to call from any state, including idle and disposed.
  Future<void> stop() async {
    if (_disposed || !_started) {
      debugPrint('[Session] stop() — not started or disposed, skipping.');
      return;
    }
    debugPrint('[Session] stop() called.');

    await _tearDown();

    _setState(_state.copyWith(status: MurojaahSessionStatus.idle));
    _emitEvent(const SessionStopped());
  }

  /// Release all resources. Must be called when the session is no longer
  /// needed (e.g. in a widget's dispose()).
  ///
  /// After [dispose], calling [start] will throw a [StateError].
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    debugPrint('[Session] dispose()');
    _tearDown();
    _eventController.close();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Tear-down (shared by stop() and dispose())
  // ---------------------------------------------------------------------------

  Future<void> _tearDown() async {
    _started = false;
    _utteranceQueue.clear();
    _prevSegmenterState = SegmenterState.idle; // E4: reset onset tracker

    await _audioSub?.cancel();
    _audioSub = null;

    if (_recorder.isRecording) {
      try {
        await _recorder.stop();
      } catch (_) {
        // Best-effort stop — ignore errors during tear-down.
      }
    }

    _segmenter.reset();
    debugPrint('[Session] Tear-down complete.');
  }

  // ---------------------------------------------------------------------------
  // Audio chunk processing
  // ---------------------------------------------------------------------------

  void _onAudioChunk(Uint8List bytes) {
    if (!_started || _disposed) return;

    // Feed bytes into the segmenter (int16 LE PCM).
    _segmenter.addBytes(bytes);

    // Update live diagnostics from the segmenter.
    final nowSpeaking = _segmenter.isSpeechDetected;

    _setState(_state.copyWith(
      currentRms: _segmenter.currentRms,
      currentPeak: _segmenter.currentPeak,
      isSpeechDetected: nowSpeaking,
      currentUtteranceDurationSeconds:
          _segmenter.currentUtteranceDurationSeconds,
    ));

    // E4: Emit SpeechStarted exactly once per utterance — only when the
    // segmenter transitions from idle → speaking. Using segmenter.state
    // (the VAD state machine) rather than the per-frame isSpeechDetected
    // flag prevents repeated events during continuous speech.
    final currentSegmenterState = _segmenter.state;
    if (_prevSegmenterState != SegmenterState.speaking &&
        currentSegmenterState == SegmenterState.speaking) {
      _emitEvent(const SpeechStarted());
      debugPrint('[Session] Speech onset detected.');
    }
    _prevSegmenterState = currentSegmenterState;

    // Check if an utterance has been finalized.
    if (currentSegmenterState == SegmenterState.utteranceReady) {
      final buf = _segmenter.consumeCompletedUtterance();
      if (buf != null) {
        final dur = buf.durationSeconds;
        _emitEvent(SpeechEnded(utteranceDurationSeconds: dur));
        debugPrint(
          '[Session] Utterance finalized: ${dur.toStringAsFixed(2)}s '
          'rms=${buf.rms.toStringAsFixed(4)}',
        );

        if (buf.isEffectivelySilent) {
          debugPrint('[Session] Utterance is effectively silent — discarding.');
          return;
        }

        _enqueueUtterance(buf);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ASR queue management
  // ---------------------------------------------------------------------------

  void _enqueueUtterance(MurojaahAudioBuffer buf) {
    _utteranceQueue.addLast(buf);

    if (_utteranceQueue.length > _maxQueueDepth) {
      _utteranceQueue.removeFirst();
      debugPrint(
        '[Session] Queue depth exceeded $_maxQueueDepth — oldest utterance dropped.',
      );
    }

    final utteranceIdx = ++_utteranceIndex;
    _emitEvent(UtteranceReady(utteranceIndex: utteranceIdx));

    if (_asrRunning) {
      debugPrint(
        '[Session] ASR busy — utterance #$utteranceIdx queued '
        '(queue length=${_utteranceQueue.length}).',
      );
      _emitEvent(UtteranceQueued(queueLength: _utteranceQueue.length));
      return;
    }

    _drainQueue();
  }

  /// Drains the utterance queue one item at a time (serialized).
  void _drainQueue() {
    if (_utteranceQueue.isEmpty || _asrRunning) return;

    final buf = _utteranceQueue.removeFirst();
    _asrRunning = true;
    unawaited(_runAsr(buf));
  }

  // ---------------------------------------------------------------------------
  // ASR + matching
  // ---------------------------------------------------------------------------

  Future<void> _runAsr(MurojaahAudioBuffer buf) async {
    final config = _config!;
    final utteranceIdx = _completedUtteranceCount + 1;

    debugPrint('[Session] ASR started for utterance #$utteranceIdx.');
    _setState(_state.copyWith(
      status: MurojaahSessionStatus.processing,
      lastBuffer: buf,
    ));
    _emitEvent(ProcessingStarted(utteranceIndex: utteranceIdx));

    AsrInferenceResult asrResult;
    try {
      asrResult = await _asrEngine.transcribeSamples(
        buf.samples,
        durationSeconds: buf.durationSeconds,
      );
    } catch (e) {
      debugPrint('[Session] ASR error: $e');
      _asrRunning = false;
      _completedUtteranceCount++;
      _handleError('ASR inference failed', e);
      // Drain next in queue (session continues after ASR error).
      _drainQueue();
      return;
    }

    debugPrint(
      '[Session] ASR completed: transcript="${asrResult.transcript}" '
      '${asrResult.timings}',
    );
    _emitEvent(TranscriptionCompleted(
      transcript: asrResult.transcript,
      asrResult: asrResult,
    ));

    // Matching
    final matchResult = MurojaahMatcher.match(
      config.expectedArabic,
      asrResult.transcript,
      threshold: config.threshold,
    );

    debugPrint(
      '[Session] Match: decision=${matchResult.decision} '
      'score=${matchResult.effectiveScore.toStringAsFixed(4)} '
      'reason="${matchResult.reason}"',
    );
    _emitEvent(MatchingCompleted(matchResult: matchResult));

    _completedUtteranceCount++;
    _asrRunning = false;

    // Update state with result.
    final nextStatus = matchResult.decision == MurojaahDecision.accept
        ? MurojaahSessionStatus.result
        : MurojaahSessionStatus.listening;

    _setState(_state.copyWith(
      status: nextStatus,
      lastAsrResult: asrResult,
      lastMatchResult: matchResult,
      completedUtteranceCount: _completedUtteranceCount,
      currentUtteranceDurationSeconds: 0.0,
      isSpeechDetected: false,
    ));

    // If accepted, stop the session automatically.
    if (matchResult.decision == MurojaahDecision.accept) {
      debugPrint('[Session] ACCEPT — stopping session.');
      await _tearDown();
      _emitEvent(const SessionStopped());
      return;
    }

    // Otherwise drain next queued utterance (if any).
    _drainQueue();
  }

  // ---------------------------------------------------------------------------
  // Error handling
  // ---------------------------------------------------------------------------

  void _handleError(String message, Object? cause) {
    debugPrint('[Session] ERROR: $message${cause != null ? " — $cause" : ""}');
    _setState(_state.copyWith(
      status: MurojaahSessionStatus.error,
      errorMessage: message,
    ));
    _emitEvent(SessionError(message: message, cause: cause));
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _setState(MurojaahSessionState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  void _emitEvent(RecitationSessionEvent event) {
    if (_disposed || _eventController.isClosed) return;
    _eventController.add(event);
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError(
        'MurojaahRecitationSession has been disposed. '
        'Create a new instance to start a new session.',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// StreamingAudioRecorder interface
// ---------------------------------------------------------------------------

/// Extension of [MurojaahAudioRecorder] that exposes a live PCM byte stream.
///
/// [MurojaahRecitationSession] requires a [StreamingAudioRecorder] because
/// it processes audio incrementally (chunk-by-chunk) rather than waiting for
/// a complete recording.
///
/// The existing [RecordAudioRecorder] does not implement this interface.
/// Use a streaming-capable implementation (e.g. based on
/// `AudioRecorder.startStream()` from the `record` package, as demonstrated
/// in [VadPocPage._StreamingRecorder]).
abstract interface class StreamingAudioRecorder implements MurojaahAudioRecorder {
  /// Broadcast stream of raw int16 LE PCM bytes at 16 kHz mono.
  ///
  /// Chunks are delivered continuously while [isRecording] is true.
  /// The stream emits [Uint8List] chunks of varying size — callers must
  /// not assume a fixed chunk size.
  Stream<Uint8List> get audioStream;
}
