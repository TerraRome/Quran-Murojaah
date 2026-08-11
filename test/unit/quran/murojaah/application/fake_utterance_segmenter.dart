/// fake_utterance_segmenter.dart
///
/// Test double for [MurojaahUtteranceSegmenter].
///
/// Allows tests to:
///   - Track how many times addBytes / addSamples was called.
///   - Inject a finalized [MurojaahAudioBuffer] on demand via
///     [emitUtterance], which sets internal state to utteranceReady.
///   - Inject errors via [throwOnNextAdd].
///   - Inspect the raw bytes / samples received.
library fake_utterance_segmenter;

import 'dart:typed_data';

import 'package:flutter_portfolio/Quran/murojaah/infrastructure/audio/murojaah_audio_buffer.dart';
import 'package:flutter_portfolio/Quran/murojaah/infrastructure/audio/murojaah_utterance_segmenter.dart';

export 'package:flutter_portfolio/Quran/murojaah/infrastructure/audio/murojaah_utterance_segmenter.dart'
    show SegmenterState;

/// Fake [MurojaahUtteranceSegmenter] for unit tests.
///
/// Does NOT perform real VAD. All state transitions are controlled
/// programmatically by the test.
class FakeUtteranceSegmenter extends MurojaahUtteranceSegmenter {
  FakeUtteranceSegmenter() : super();

  // ── Call tracking ─────────────────────────────────────────────────────────

  /// All byte chunks passed to [addBytes].
  final List<List<int>> addBytesCalls = [];

  /// All sample arrays passed to [addSamples].
  final List<Float32List> addSamplesCalls = [];

  /// Number of times [reset] was called.
  int resetCallCount = 0;

  /// Number of times [consumeCompletedUtterance] was called.
  int consumeCallCount = 0;

  // ── Injectable state ──────────────────────────────────────────────────────

  /// Set by [emitUtterance] — returned on the next [consumeCompletedUtterance].
  MurojaahAudioBuffer? _pendingUtterance;

  /// If non-null, [addBytes] and [addSamples] throw this error.
  Exception? throwOnNextAdd;

  /// RMS to expose via [currentRms].
  double fakeRms = 0.0;

  /// Peak to expose via [currentPeak].
  double fakePeak = 0.0;

  /// Whether the last frame is classified as speech.
  bool fakeSpeechDetected = false;

  // ── Overrides ─────────────────────────────────────────────────────────────

  @override
  SegmenterState get state =>
      _pendingUtterance != null ? SegmenterState.utteranceReady : SegmenterState.idle;

  @override
  double get currentRms => fakeRms;

  @override
  double get currentPeak => fakePeak;

  @override
  bool get isSpeechDetected => fakeSpeechDetected;

  @override
  double get currentUtteranceDurationSeconds => 0.0;

  @override
  void addBytes(List<int> bytes) {
    if (throwOnNextAdd != null) {
      final err = throwOnNextAdd!;
      throwOnNextAdd = null;
      throw err;
    }
    addBytesCalls.add(List.unmodifiable(bytes));
  }

  @override
  void addSamples(Float32List samples) {
    if (throwOnNextAdd != null) {
      final err = throwOnNextAdd!;
      throwOnNextAdd = null;
      throw err;
    }
    addSamplesCalls.add(Float32List.fromList(samples));
  }

  @override
  MurojaahAudioBuffer? consumeCompletedUtterance() {
    consumeCallCount++;
    final buf = _pendingUtterance;
    _pendingUtterance = null;
    return buf;
  }

  @override
  void reset() {
    resetCallCount++;
    _pendingUtterance = null;
    fakeRms = 0.0;
    fakePeak = 0.0;
    fakeSpeechDetected = false;
  }

  // ── Test helpers ──────────────────────────────────────────────────────────

  /// Schedule [buffer] to be returned by the next
  /// [consumeCompletedUtterance] call.
  ///
  /// Also marks [fakeSpeechDetected] true so [addBytes] triggers a
  /// speech-onset event in the session before the utterance is consumed.
  void emitUtterance(MurojaahAudioBuffer buffer) {
    _pendingUtterance = buffer;
    fakeSpeechDetected = true;
  }

  /// Convenience: build a fake utterance with [durationSeconds] of
  /// synthesized non-silent audio and call [emitUtterance].
  void emitSyntheticUtterance({
    double durationSeconds = 2.0,
    int sampleRate = 16000,
    double amplitude = 0.1,
  }) {
    final sampleCount = (sampleRate * durationSeconds).round();
    final samples = Float32List(sampleCount);
    for (int i = 0; i < sampleCount; i++) {
      samples[i] = amplitude * ((i % 2 == 0) ? 1.0 : -1.0);
    }
    emitUtterance(MurojaahAudioBuffer(
      samples: samples,
      sampleRate: sampleRate,
      channels: 1,
    ));
  }
}
