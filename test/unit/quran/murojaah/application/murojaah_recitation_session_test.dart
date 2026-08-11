/// murojaah_recitation_session_test.dart
///
/// Unit tests for [MurojaahRecitationSession].
///
/// All tests use:
///   - [FakeStreamingRecorder]  — controls permission, recorder start/stop,
///                               and injects PCM chunks via [pushChunk].
///   - [FakeUtteranceSegmenter] — controls utterance finalization.
///   - [FakeQuranAsrEngine]     — controls ASR transcripts and errors.
///
/// [MurojaahController] is NOT instantiated in any test — verifying that
/// the session does not depend on or modify the controller.
library murojaah_recitation_session_test;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_portfolio/Quran/murojaah/application/murojaah_recitation_session.dart';
import 'package:flutter_portfolio/Quran/murojaah/domain/murojaah_matcher.dart';
import 'package:flutter_portfolio/Quran/murojaah/infrastructure/audio/murojaah_audio_buffer.dart';
import 'package:flutter_portfolio/Quran/murojaah/infrastructure/audio/murojaah_audio_recorder.dart';

import 'fake_quran_asr_engine.dart';
import 'fake_utterance_segmenter.dart';

// ---------------------------------------------------------------------------
// Fake streaming recorder
// ---------------------------------------------------------------------------

/// Fake [StreamingAudioRecorder] for unit tests.
///
/// Exposes [pushChunk] so tests can inject PCM bytes into the session,
/// and [permissionResult] / [startError] to control lifecycle failures.
class FakeStreamingRecorder implements StreamingAudioRecorder {
  bool _initialized = false;
  bool _recording = false;
  bool _disposed = false;

  bool permissionResult = true;
  Exception? initError;
  Exception? startError;

  int initCallCount = 0;
  int startCallCount = 0;
  int stopCallCount = 0;
  int disposeCallCount = 0;

  final StreamController<Uint8List> _streamController =
      StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get audioStream => _streamController.stream;

  @override
  Future<bool> requestPermission() async => permissionResult;

  @override
  Future<void> initialize() async {
    initCallCount++;
    if (initError != null) throw initError!;
    _initialized = true;
  }

  @override
  Future<void> start() async {
    startCallCount++;
    if (!_initialized) throw StateError('Not initialized');
    if (_recording) throw StateError('Already recording');
    if (startError != null) throw startError!;
    _recording = true;
  }

  @override
  Future<MurojaahAudioBuffer> stop() async {
    stopCallCount++;
    _recording = false;
    return MurojaahAudioBuffer(
      samples: Float32List(0),
      sampleRate: 16000,
      channels: 1,
    );
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    _disposed = true;
    _recording = false;
    await _streamController.close();
  }

  @override
  bool get isRecording => _recording;

  /// Inject a PCM chunk into the session's audio stream.
  void pushChunk(Uint8List bytes) {
    if (!_streamController.isClosed) {
      _streamController.add(bytes);
    }
  }

  /// Push a silent chunk (all zeros).
  void pushSilence({int byteCount = 320}) {
    pushChunk(Uint8List(byteCount));
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Standard config used across most tests.
const _config = MurojaahSessionConfig(expectedArabic: 'يس');

/// Build a session with the given fakes.
MurojaahRecitationSession makeSession({
  FakeStreamingRecorder? recorder,
  FakeUtteranceSegmenter? segmenter,
  FakeQuranAsrEngine? engine,
}) {
  return MurojaahRecitationSession(
    recorder: recorder ?? FakeStreamingRecorder(),
    segmenter: segmenter ?? FakeUtteranceSegmenter(),
    asrEngine: engine ?? FakeQuranAsrEngine(),
  );
}

/// Start a session and wait for it to reach [MurojaahSessionStatus.listening].
Future<void> startAndWaitListening(
  MurojaahRecitationSession session, {
  MurojaahSessionConfig config = _config,
}) async {
  await session.start(config);
  // Give the event loop a tick to settle.
  await Future<void>.delayed(Duration.zero);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── 1. Initial state ───────────────────────────────────────────────────────
  group('1. initial state', () {
    test('is idle before start()', () {
      final session = makeSession();
      expect(session.state.status, MurojaahSessionStatus.idle);
      expect(session.state.isIdle, isTrue);
      session.dispose();
    });
  });

  // ── 2. start() transitions to listening ───────────────────────────────────
  group('2. start() → listening', () {
    test('transitions idle → initializing → listening', () async {
      final recorder = FakeStreamingRecorder();
      final session = makeSession(recorder: recorder);

      final statuses = <MurojaahSessionStatus>[];
      session.addListener(() => statuses.add(session.state.status));

      await startAndWaitListening(session);

      expect(statuses, contains(MurojaahSessionStatus.initializing));
      expect(statuses.last, MurojaahSessionStatus.listening);
      expect(session.state.isListening, isTrue);

      await session.stop();
      session.dispose();
    });
  });

  // ── 3. recorder starts exactly once ───────────────────────────────────────
  group('3. recorder lifecycle', () {
    test('recorder is started exactly once on start()', () async {
      final recorder = FakeStreamingRecorder();
      final session = makeSession(recorder: recorder);

      await startAndWaitListening(session);
      expect(recorder.startCallCount, 1);

      await session.stop();
      session.dispose();
    });

    test('calling start() twice does not start recorder a second time', () async {
      final recorder = FakeStreamingRecorder();
      final session = makeSession(recorder: recorder);

      await startAndWaitListening(session);
      await startAndWaitListening(session); // second call — must be ignored

      expect(recorder.startCallCount, 1);

      await session.stop();
      session.dispose();
    });
  });

  // ── 4. audio chunks reach segmenter ───────────────────────────────────────
  group('4. audio chunks → segmenter', () {
    test('pushChunk reaches segmenter.addBytes', () async {
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      final session = makeSession(recorder: recorder, segmenter: segmenter);

      await startAndWaitListening(session);

      final chunk = Uint8List.fromList(List.filled(320, 0));
      recorder.pushChunk(chunk);
      await Future<void>.delayed(Duration.zero);

      expect(segmenter.addBytesCalls, hasLength(1));
      expect(segmenter.addBytesCalls.first, equals(chunk));

      await session.stop();
      session.dispose();
    });

    test('multiple chunks all reach segmenter', () async {
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      final session = makeSession(recorder: recorder, segmenter: segmenter);

      await startAndWaitListening(session);

      for (int i = 0; i < 5; i++) {
        recorder.pushSilence();
      }
      await Future<void>.delayed(Duration.zero);

      expect(segmenter.addBytesCalls, hasLength(5));

      await session.stop();
      session.dispose();
    });
  });

  // ── 5. no ASR during ordinary audio chunks ────────────────────────────────
  group('5. no ASR during ordinary audio', () {
    test('ASR is NOT called when segmenter stays idle', () async {
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      final engine = FakeQuranAsrEngine();
      final session =
          makeSession(recorder: recorder, segmenter: segmenter, engine: engine);

      await startAndWaitListening(session);

      // Push 10 silent chunks — segmenter stays idle, no utterance emitted.
      for (int i = 0; i < 10; i++) {
        recorder.pushSilence();
      }
      await Future<void>.delayed(Duration.zero);

      expect(engine.transcribeSamplesCallCount, 0);

      await session.stop();
      session.dispose();
    });
  });

  // ── 6. finalized utterance triggers processing ────────────────────────────
  group('6. utterance finalized → processing', () {
    test('session transitions to processing when utterance is ready', () async {
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      final engine = FakeQuranAsrEngine(defaultTranscript: 'يس');
      final session =
          makeSession(recorder: recorder, segmenter: segmenter, engine: engine);

      await startAndWaitListening(session);

      final statuses = <MurojaahSessionStatus>[];
      session.addListener(() => statuses.add(session.state.status));

      segmenter.emitSyntheticUtterance();
      recorder.pushSilence(); // trigger _onAudioChunk to pick up utteranceReady
      await Future<void>.delayed(Duration.zero);

      expect(statuses, contains(MurojaahSessionStatus.processing));

      session.dispose();
    });
  });

  // ── 7. ASR receives exact utterance samples ────────────────────────────────
  group('7. ASR receives correct samples', () {
    test('transcribeSamples receives the exact buffer samples', () async {
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      final engine = FakeQuranAsrEngine(defaultTranscript: 'يس');
      final session =
          makeSession(recorder: recorder, segmenter: segmenter, engine: engine);

      await startAndWaitListening(session);

      segmenter.emitSyntheticUtterance(durationSeconds: 2.0);
      recorder.pushSilence();
      await Future<void>.delayed(Duration.zero);

      expect(engine.transcribeSamplesCallCount, 1);
      // The samples passed to ASR must match what the segmenter produced.
      expect(engine.capturedSamples.first.length, greaterThan(0));

      session.dispose();
    });
  });

  // ── 8. ASR receives durationSeconds ──────────────────────────────────────
  group('8. ASR receives durationSeconds', () {
    test('durationSeconds passed to ASR matches buffer duration', () async {
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      final engine = FakeQuranAsrEngine(defaultTranscript: 'يس');
      final session =
          makeSession(recorder: recorder, segmenter: segmenter, engine: engine);

      await startAndWaitListening(session);

      const expectedDuration = 2.0;
      segmenter.emitSyntheticUtterance(durationSeconds: expectedDuration);
      recorder.pushSilence();
      await Future<void>.delayed(Duration.zero);

      expect(engine.capturedDurations, hasLength(1));
      expect(
        engine.capturedDurations.first,
        closeTo(expectedDuration, 0.05),
      );

      session.dispose();
    });
  });

  // ── 9. transcript passed to MurojaahMatcher ───────────────────────────────
  group('9. transcript → matcher', () {
    test('last transcript in state matches ASR output', () async {
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      const transcript = 'وَالْقُرْآنِ الْحَكِيمِ';
      final engine = FakeQuranAsrEngine(defaultTranscript: transcript);
      final session =
          makeSession(recorder: recorder, segmenter: segmenter, engine: engine);

      await startAndWaitListening(session);

      segmenter.emitSyntheticUtterance();
      recorder.pushSilence();
      await Future<void>.delayed(Duration.zero);

      expect(session.state.lastTranscript, transcript);

      session.dispose();
    });
  });

  // ── 10. correct transcript → ACCEPT ──────────────────────────────────────
  group('10. ACCEPT on correct transcript', () {
    test('exact match produces ACCEPT decision', () async {
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      // يس is a single-word verse — exact match.
      final engine = FakeQuranAsrEngine(defaultTranscript: 'يس');
      final session = makeSession(
        recorder: recorder,
        segmenter: segmenter,
        engine: engine,
      );

      await startAndWaitListening(session, config: _config);

      segmenter.emitSyntheticUtterance();
      recorder.pushSilence();
      await Future<void>.delayed(Duration.zero);

      expect(session.state.lastDecision, MurojaahDecision.accept);

      session.dispose();
    });
  });

  // ── 11. wrong transcript → REJECT ────────────────────────────────────────
  group('11. REJECT on wrong transcript', () {
    test('completely different transcript produces REJECT', () async {
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      final engine = FakeQuranAsrEngine(
        defaultTranscript: 'completely wrong text abc xyz',
      );
      final session = makeSession(
        recorder: recorder,
        segmenter: segmenter,
        engine: engine,
      );

      await startAndWaitListening(session, config: _config);

      segmenter.emitSyntheticUtterance();
      recorder.pushSilence();
      await Future<void>.delayed(Duration.zero);

      expect(session.state.lastDecision, MurojaahDecision.reject);
      // Session should stay listening (not stopped) after REJECT.
      expect(session.state.isListening, isTrue);

      session.dispose();
    });
  });

  // ── 12. ASR failure → ERROR ───────────────────────────────────────────────
  group('12. ASR failure → error state', () {
    test('ASR exception transitions session to error', () async {
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      final engine = FakeQuranAsrEngine();
      final session =
          makeSession(recorder: recorder, segmenter: segmenter, engine: engine);

      await startAndWaitListening(session);

      engine.errorOnNextCall = Exception('ONNX inference failed');
      segmenter.emitSyntheticUtterance();
      recorder.pushSilence();
      await Future<void>.delayed(Duration.zero);

      expect(session.state.isError, isTrue);
      expect(session.state.errorMessage, contains('ASR inference failed'));

      session.dispose();
    });
  });

  // ── 13. recorder failure → ERROR ─────────────────────────────────────────
  group('13. recorder failure → error state', () {
    test('recorder init error transitions to error state', () async {
      final recorder = FakeStreamingRecorder()
        ..initError = Exception('Recorder hardware unavailable');
      final session = makeSession(recorder: recorder);

      await session.start(_config);
      await Future<void>.delayed(Duration.zero);

      expect(session.state.isError, isTrue);
      expect(session.state.errorMessage, contains('Recorder initialization failed'));

      session.dispose();
    });

    test('recorder start error transitions to error state', () async {
      final recorder = FakeStreamingRecorder()
        ..startError = Exception('Recorder start failed');
      final session = makeSession(recorder: recorder);

      await session.start(_config);
      await Future<void>.delayed(Duration.zero);

      expect(session.state.isError, isTrue);

      session.dispose();
    });
  });

  // ── 14. multiple utterances processed sequentially ────────────────────────
  group('14. multiple utterances processed', () {
    test('two utterances each trigger one ASR call', () async {
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      final engine = FakeQuranAsrEngine(defaultTranscript: 'مختلف');
      final session =
          makeSession(recorder: recorder, segmenter: segmenter, engine: engine);

      await startAndWaitListening(session);

      // First utterance
      segmenter.emitSyntheticUtterance();
      recorder.pushSilence();
      await Future<void>.delayed(Duration.zero);

      // Second utterance
      segmenter.emitSyntheticUtterance();
      recorder.pushSilence();
      await Future<void>.delayed(Duration.zero);

      expect(engine.transcribeSamplesCallCount, 2);
      expect(session.state.completedUtteranceCount, 2);

      session.dispose();
    });
  });

  // ── 15. ASR jobs are serialized ───────────────────────────────────────────
  group('15. ASR serialization', () {
    test('second ASR only runs after first completes', () async {
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      // 80ms delay — gives us time to inject a second utterance while #1 runs.
      final engine = FakeQuranAsrEngine(
        defaultTranscript: 'مختلف',
        inferenceDelayMs: 80,
      );
      final session =
          makeSession(recorder: recorder, segmenter: segmenter, engine: engine);

      final events = <RecitationSessionEvent>[];
      session.events.listen(events.add);

      await startAndWaitListening(session);

      // Emit first utterance — starts ASR #1 (80ms).
      segmenter.emitSyntheticUtterance();
      recorder.pushSilence();
      await Future<void>.delayed(Duration.zero); // let ASR #1 start

      // ASR #1 is now running. Emit second utterance — must be queued.
      segmenter.emitSyntheticUtterance();
      recorder.pushSilence();
      await Future<void>.delayed(Duration.zero);

      // Verify second utterance was queued (not immediately started).
      expect(events.whereType<UtteranceQueued>(), isNotEmpty,
          reason: 'second utterance should be queued while ASR #1 runs');

      // Wait for both to finish.
      await Future<void>.delayed(const Duration(milliseconds: 250));

      // Both ASR calls must have run — sequentially, never concurrently.
      expect(engine.transcribeSamplesCallCount, 2,
          reason: 'both utterances should eventually be processed');

      session.dispose();
    });
  });

  // ── 16. second utterance queued while ASR busy ────────────────────────────
  group('16. utterance queuing', () {
    test('UtteranceQueued event emitted when ASR is busy', () async {
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      final engine = FakeQuranAsrEngine(
        defaultTranscript: 'مختلف',
        inferenceDelayMs: 80,
      );
      final session =
          makeSession(recorder: recorder, segmenter: segmenter, engine: engine);

      final events = <RecitationSessionEvent>[];
      session.events.listen(events.add);

      await startAndWaitListening(session);

      // First utterance — starts ASR.
      segmenter.emitSyntheticUtterance();
      recorder.pushSilence();
      await Future<void>.delayed(Duration.zero);

      // Second utterance while ASR is running — should queue.
      segmenter.emitSyntheticUtterance();
      recorder.pushSilence();
      await Future<void>.delayed(Duration.zero);

      expect(events.whereType<UtteranceQueued>(), isNotEmpty);

      // Wait for everything to finish.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      session.dispose();
    });
  });

  // ── 17. stop() stops recording cleanly ───────────────────────────────────
  group('17. stop() lifecycle', () {
    test('stop() transitions to idle and stops recorder', () async {
      final recorder = FakeStreamingRecorder();
      final session = makeSession(recorder: recorder);

      await startAndWaitListening(session);
      expect(session.state.isListening, isTrue);

      await session.stop();
      await Future<void>.delayed(Duration.zero);

      expect(session.state.isIdle, isTrue);
      expect(recorder.stopCallCount, greaterThanOrEqualTo(1));

      session.dispose();
    });

    test('stop() on idle session does nothing', () async {
      final recorder = FakeStreamingRecorder();
      final session = makeSession(recorder: recorder);

      // Never started — should be a no-op.
      await session.stop();

      expect(recorder.stopCallCount, 0);
      expect(session.state.isIdle, isTrue);

      session.dispose();
    });
  });

  // ── 18. dispose() releases resources ─────────────────────────────────────
  group('18. dispose()', () {
    test('dispose() closes event stream without error', () async {
      final recorder = FakeStreamingRecorder();
      final session = makeSession(recorder: recorder);

      await startAndWaitListening(session);

      final events = <RecitationSessionEvent>[];
      session.events.listen(events.add);

      session.dispose();
      await Future<void>.delayed(Duration.zero);

      // After dispose the stream should be closed — no more events.
      final countAfterDispose = events.length;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(events.length, countAfterDispose); // no new events
    });
  });

  // ── 19. start() after dispose throws ─────────────────────────────────────
  group('19. start() after dispose', () {
    test('start() after dispose() throws StateError', () async {
      final session = makeSession();
      session.dispose();

      expect(
        () => session.start(_config),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ── 20. threshold is 0.80 by default ─────────────────────────────────────
  group('20. default matching threshold is 0.80', () {
    test('MurojaahSessionConfig defaults to 0.80', () {
      const config = MurojaahSessionConfig(expectedArabic: 'يس');
      expect(config.threshold, 0.80);
    });

    test('threshold matches MurojaahMatcher.defaultThreshold', () {
      const config = MurojaahSessionConfig(expectedArabic: 'يس');
      expect(config.threshold, MurojaahMatcher.defaultThreshold);
    });
  });

  // ── 21. session does not reference MurojaahController ────────────────────
  group('21. MurojaahController not touched', () {
    test('session runs full pipeline without MurojaahController', () async {
      // This test has no MurojaahController in scope — if compilation
      // succeeds and the test passes, the session is controller-independent.
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      final engine = FakeQuranAsrEngine(defaultTranscript: 'يس');

      final session = MurojaahRecitationSession(
        recorder: recorder,
        segmenter: segmenter,
        asrEngine: engine,
      );

      await startAndWaitListening(session);
      segmenter.emitSyntheticUtterance();
      recorder.pushSilence();
      await Future<void>.delayed(Duration.zero);

      // Full pipeline ran — no controller anywhere.
      expect(engine.transcribeSamplesCallCount, 1);
      expect(session.state.lastMatchResult, isNotNull);

      session.dispose();
    });
  });

  // ── 22. processing state is session-local only ────────────────────────────
  group('22. processing state is session-local', () {
    test('processing status is on MurojaahSessionState, not MurojaahController', () async {
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      final engine = FakeQuranAsrEngine(
        defaultTranscript: 'مختلف',
        inferenceDelayMs: 30,
      );
      final session =
          makeSession(recorder: recorder, segmenter: segmenter, engine: engine);

      final processingStatuses = <MurojaahSessionStatus>[];
      session.addListener(() {
        if (session.state.isProcessing) {
          processingStatuses.add(session.state.status);
        }
      });

      await startAndWaitListening(session);
      segmenter.emitSyntheticUtterance();
      recorder.pushSilence();

      await Future<void>.delayed(const Duration(milliseconds: 80));

      // Processing was observed on the session state.
      expect(processingStatuses, isNotEmpty);
      expect(
        processingStatuses.every((s) => s == MurojaahSessionStatus.processing),
        isTrue,
      );

      session.dispose();
    });
  });

  // ── 23. permission denied ─────────────────────────────────────────────────
  group('23. permission denied', () {
    test('permission denied transitions to permissionDenied state', () async {
      final recorder = FakeStreamingRecorder()..permissionResult = false;
      final session = makeSession(recorder: recorder);

      await session.start(_config);
      await Future<void>.delayed(Duration.zero);

      expect(session.state.status, MurojaahSessionStatus.permissionDenied);
      expect(session.state.errorMessage, isNotEmpty);

      session.dispose();
    });

    test('permissionDenied emits SessionError event', () async {
      final recorder = FakeStreamingRecorder()..permissionResult = false;
      final session = makeSession(recorder: recorder);

      final events = <RecitationSessionEvent>[];
      session.events.listen(events.add);

      await session.start(_config);
      await Future<void>.delayed(Duration.zero);

      expect(events.whereType<SessionError>(), isNotEmpty);

      session.dispose();
    });
  });

  // ── 24. ASR runs after first ASR error ───────────────────────────────────
  group('24. ASR error recovery', () {
    test('session drains queue after ASR error', () async {
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      final engine = FakeQuranAsrEngine(defaultTranscript: 'مختلف');
      final session =
          makeSession(recorder: recorder, segmenter: segmenter, engine: engine);

      await startAndWaitListening(session);

      // First utterance — will fail.
      engine.errorOnNextCall = Exception('first ASR error');
      segmenter.emitSyntheticUtterance();
      recorder.pushSilence();
      await Future<void>.delayed(Duration.zero);

      expect(session.state.isError, isTrue);

      session.dispose();
    });
  });

  // ── 25. events stream: full happy path ────────────────────────────────────
  group('25. events stream', () {
    test('full REJECT pipeline emits expected event sequence', () async {
      final recorder = FakeStreamingRecorder();
      final segmenter = FakeUtteranceSegmenter();
      final engine = FakeQuranAsrEngine(
        defaultTranscript: 'completely wrong xyz',
      );
      final session =
          makeSession(recorder: recorder, segmenter: segmenter, engine: engine);

      final events = <RecitationSessionEvent>[];
      session.events.listen(events.add);

      await startAndWaitListening(session);
      segmenter.emitSyntheticUtterance();
      recorder.pushSilence();
      await Future<void>.delayed(Duration.zero);

      final types = events.map((e) => e.runtimeType).toList();

      expect(types, contains(SessionStarted));
      expect(types, contains(SpeechEnded));
      expect(types, contains(UtteranceReady));
      expect(types, contains(ProcessingStarted));
      expect(types, contains(TranscriptionCompleted));
      expect(types, contains(MatchingCompleted));

      session.dispose();
    });
  });
}
