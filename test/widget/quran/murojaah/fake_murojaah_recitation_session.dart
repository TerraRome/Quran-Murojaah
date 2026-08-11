/// fake_murojaah_recitation_session.dart
///
/// Controllable test double for [MurojaahRecitationSession].
///
/// Does NOT touch microphone, ONNX, or VAD. All state transitions and events
/// are driven programmatically by the test via [simulateState] and
/// [simulateEvent].
library fake_murojaah_recitation_session;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_portfolio/Quran/murojaah/application/murojaah_recitation_session.dart';
import 'package:flutter_portfolio/Quran/murojaah/application/murojaah_session_state.dart';
import 'package:flutter_portfolio/Quran/murojaah/application/recitation_session_event.dart';
import 'package:flutter_portfolio/Quran/murojaah/infrastructure/asr/quran_asr_result.dart';
import 'package:flutter_portfolio/Quran/murojaah/infrastructure/audio/murojaah_audio_recorder.dart';
import 'package:flutter_portfolio/Quran/murojaah/infrastructure/audio/murojaah_utterance_segmenter.dart';
import 'package:flutter_portfolio/Quran/murojaah/infrastructure/asr/quran_onnx_model.dart';

// ---------------------------------------------------------------------------
// Minimal no-op dependencies required by MurojaahRecitationSession constructor
// ---------------------------------------------------------------------------

class _NoOpRecorder implements MurojaahAudioRecorder {
  @override
  bool get isRecording => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> start() async {}
  @override
  Future<MurojaahAudioBuffer> stop() async => MurojaahAudioBuffer(
        samples: Float32List(0),
        sampleRate: 16000,
        channels: 1,
      );
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> dispose() async {}
}

class _NoOpAsrEngine implements QuranAsrEngine {
  @override
  Future<AsrInferenceResult> transcribeWav(bytes) async => _empty();
  @override
  Future<AsrInferenceResult> transcribeSamples(samples,
      {required double durationSeconds}) async => _empty();
  @override
  Future<void> warmUp() async {}

  @override
  Future<void> dispose() async {}

  AsrInferenceResult _empty() => AsrInferenceResult(
        transcript: '',
        audioDurationSeconds: 0,
        timings: const AsrTimings(
          modelLoadMs: 0,
          preprocessMs: 0,
          inferenceMs: 0,
          decodeMs: 0,
        ),
      );
}

// ---------------------------------------------------------------------------
// Fake session
// ---------------------------------------------------------------------------

/// Widget-test double for [MurojaahRecitationSession].
///
/// Inherits from the real class (so it satisfies `is MurojaahRecitationSession`)
/// but overrides [start], [stop], [state], and [events] completely, so no real
/// audio or ONNX infrastructure is touched.
class FakeMurojaahRecitationSession extends MurojaahRecitationSession {
  FakeMurojaahRecitationSession()
      : super(
          recorder: _NoOpRecorder(),
          segmenter: MurojaahUtteranceSegmenter(),
          asrEngine: _NoOpAsrEngine(),
        );

  // ── Call tracking ────────────────────────────────────────────────────────

  int startCallCount = 0;
  int stopCallCount = 0;
  MurojaahSessionConfig? lastStartConfig;

  // ── State and events ─────────────────────────────────────────────────────

  MurojaahSessionState _fakeState = const MurojaahSessionState.idle();

  final StreamController<RecitationSessionEvent> _fakeEvents =
      StreamController<RecitationSessionEvent>.broadcast();

  @override
  MurojaahSessionState get state => _fakeState;

  @override
  Stream<RecitationSessionEvent> get events => _fakeEvents.stream;

  // ── Test control API ─────────────────────────────────────────────────────

  /// Push a new state snapshot and notify listeners (triggers setState in page).
  void simulateState(MurojaahSessionState newState) {
    _fakeState = newState;
    notifyListeners();
  }

  /// Push an event into the events stream (triggers _onSessionEvent in page).
  void simulateEvent(RecitationSessionEvent event) {
    _fakeEvents.add(event);
  }

  /// Convenience: simulate a MatchingCompleted event with a given transcript
  /// available in session state. Sets [lastAsrResult] on the state first so
  /// the page's _onMatchingCompleted can read `state.lastAsrResult?.transcript`.
  void simulateMatchingCompleted({
    required MurojaahMatchResult matchResult,
    required String transcript,
  }) {
    // Set state so the page can read transcript from state.lastAsrResult
    _fakeState = _fakeState.copyWith(
      status: MurojaahSessionStatus.result,
      lastAsrResult: AsrInferenceResult(
        transcript: transcript,
        audioDurationSeconds: 1.0,
        timings: const AsrTimings(
          modelLoadMs: 0,
          preprocessMs: 1,
          inferenceMs: 1,
          decodeMs: 1,
        ),
      ),
      lastMatchResult: matchResult,
    );
    notifyListeners();
    _fakeEvents.add(MatchingCompleted(matchResult: matchResult));
  }

  // ── Overrides ────────────────────────────────────────────────────────────

  @override
  Future<void> start(MurojaahSessionConfig config) async {
    startCallCount++;
    lastStartConfig = config;
    simulateState(_fakeState.copyWith(status: MurojaahSessionStatus.listening));
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    simulateState(const MurojaahSessionState.idle());
    // Emit SessionStopped so the page's _onSessionEvent can arm the
    // auto-advance timer (E6 continuous-listening behaviour).
    _fakeEvents.add(const SessionStopped());
  }

  @override
  void dispose() {
    _fakeEvents.close();
    // Do NOT call super.dispose() — the real session's dispose() would try to
    // tear down the no-op recorder and close the real event controller, which
    // would conflict with our override. The ChangeNotifier disposal is handled
    // by calling super directly on ChangeNotifier.
  }
}
