/// murojaah_utterance_segmenter.dart
///
/// State-machine utterance boundary detector for the Murojaah ASR pipeline.
///
/// Pipeline:
///   RecordAudioRecorder (raw PCM int16 bytes via startStream)
///     → [addBytes]  — feed raw int16 LE bytes from microphone
///     → frame slicing
///     → [MurojaahVad.isSpeech]
///     → state machine: IDLE → SPEAKING → UTTERANCE_READY
///     → [consumeCompletedUtterance] → MurojaahAudioBuffer
///
/// OR if Float32 samples are already available:
///     → [addSamples]  — feed float32 PCM directly
///
/// The segmenter does NOT run ASR. It only detects utterance boundaries.
///
/// State machine:
///
///   IDLE
///     ↓  consecutiveSpeechFrames ≥ config.consecutiveSpeechFrames
///   SPEAKING
///     ↓  consecutiveSilenceFrames ≥ config.consecutiveSilenceFrames
///   UTTERANCE_READY
///     ↓  consumeCompletedUtterance()
///   IDLE
///
/// Memory cap: when the speaking buffer exceeds [VadConfig.maxUtteranceSamples],
/// no new samples are appended. The segmenter waits for natural silence to
/// finalize. This prevents unbounded memory growth during very long utterances.
library murojaah_utterance_segmenter;

import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import 'energy_vad.dart';
import 'murojaah_audio_buffer.dart';
import 'murojaah_vad.dart';

export 'energy_vad.dart' show VadConfig;
export 'murojaah_vad.dart';

// ---------------------------------------------------------------------------
// State enum
// ---------------------------------------------------------------------------

/// States of [MurojaahUtteranceSegmenter].
enum SegmenterState {
  /// No speech detected; waiting for utterance onset.
  idle,

  /// Speech detected; accumulating utterance samples.
  speaking,

  /// Utterance finalized; waiting for caller to consume via
  /// [MurojaahUtteranceSegmenter.consumeCompletedUtterance].
  utteranceReady,
}

// ---------------------------------------------------------------------------
// Segmenter
// ---------------------------------------------------------------------------

/// Incremental utterance boundary detector.
///
/// Feed PCM chunks incrementally via [addSamples] or [addBytes].
/// Poll [state] and call [consumeCompletedUtterance] when
/// [SegmenterState.utteranceReady].
///
/// Example:
/// ```dart
/// final seg = MurojaahUtteranceSegmenter();
/// // From a microphone stream:
/// stream.listen((bytes) {
///   seg.addBytes(bytes);
///   final buf = seg.consumeCompletedUtterance();
///   if (buf != null) {
///     // Run ASR on buf — only after utterance is finalized.
///   }
/// });
/// ```
class MurojaahUtteranceSegmenter {
  MurojaahUtteranceSegmenter({
    MurojaahVad? vad,
    VadConfig? config,
  })  : config = config ?? const VadConfig(),
        _vad = vad ?? EnergyVad(config: config ?? const VadConfig());

  final VadConfig config;
  final MurojaahVad _vad;

  // -------------------------------------------------------------------------
  // Public diagnostics (read-only)
  // -------------------------------------------------------------------------

  /// Current state of the segmenter.
  SegmenterState get state => _state;
  SegmenterState _state = SegmenterState.idle;

  /// RMS of the most recently processed VAD frame.
  double get currentRms => _currentRms;
  double _currentRms = 0.0;

  /// Peak amplitude of the most recently processed VAD frame.
  double get currentPeak => _currentPeak;
  double _currentPeak = 0.0;

  /// Whether the most recent VAD frame was classified as speech.
  bool get isSpeechDetected => _isSpeechDetected;
  bool _isSpeechDetected = false;

  /// Duration of the utterance currently being accumulated (seconds).
  /// Returns 0.0 when not in [SegmenterState.speaking].
  double get currentUtteranceDurationSeconds {
    if (_state != SegmenterState.speaking) return 0.0;
    return _speakingBuffer.length / config.sampleRate.toDouble();
  }

  /// Total Float32 samples pushed into the segmenter since construction
  /// or last [reset].
  int get totalSamples => _totalSamples;
  int _totalSamples = 0;

  /// Number of utterances finalized (consumed) since construction or
  /// last [reset].
  int get finalizedUtteranceCount => _finalizedUtteranceCount;
  int _finalizedUtteranceCount = 0;

  // -------------------------------------------------------------------------
  // Private state
  // -------------------------------------------------------------------------

  /// Rolling ring buffer for pre-speech padding.
  /// Capacity = [VadConfig.preSpeechPaddingSamples].
  final Queue<double> _preBuffer = Queue<double>();

  /// Accumulates samples from utterance onset through to post-speech padding.
  final List<double> _speakingBuffer = [];

  /// Leftover bytes between [addBytes] calls (partial int16 frames).
  final List<int> _byteAccum = [];

  /// Leftover float32 samples between [addSamples] calls (sub-frame tail).
  final List<double> _sampleAccum = [];

  int _consecutiveSpeechFrames = 0;
  int _consecutiveSilenceFrames = 0;

  /// Set by [flush]. While true, [addBytes] and [addSamples] ignore input so
  /// nothing can arrive after the stream has been finalized. Cleared by
  /// [reset] when a new stream starts.
  bool _closed = false;

  // -------------------------------------------------------------------------
  // Primary API
  // -------------------------------------------------------------------------

  /// Feed raw PCM int16 little-endian bytes from the microphone stream.
  ///
  /// Frames are extracted internally. Incomplete frames are buffered across
  /// calls so chunk boundaries do not affect segmentation correctness.
  void addBytes(List<int> bytes) {
    if (_closed) return;
    _byteAccum.addAll(bytes);
    final bytesPerFrame = config.samplesPerFrame * 2; // int16 = 2 bytes
    while (_byteAccum.length >= bytesPerFrame) {
      final frameBytes = _byteAccum.sublist(0, bytesPerFrame);
      _byteAccum.removeRange(0, bytesPerFrame);
      _processFrame(_int16BytesToFloat32(frameBytes));
    }
  }

  /// Feed Float32 PCM samples directly.
  ///
  /// Sub-frame tails are buffered across calls so arbitrary chunk sizes
  /// are handled correctly.
  void addSamples(Float32List samples) {
    if (_closed) return;
    _sampleAccum.addAll(samples);
    while (_sampleAccum.length >= config.samplesPerFrame) {
      final frame = Float32List.fromList(
        _sampleAccum.sublist(0, config.samplesPerFrame),
      );
      _sampleAccum.removeRange(0, config.samplesPerFrame);
      _processFrame(frame);
    }
  }

  /// Returns the finalized [MurojaahAudioBuffer] and transitions back to
  /// [SegmenterState.idle], or returns `null` if no utterance is ready.
  ///
  /// Prefer this over throwing: callers can poll without try/catch.
  MurojaahAudioBuffer? consumeCompletedUtterance() {
    if (_state != SegmenterState.utteranceReady) return null;

    final buffer = MurojaahAudioBuffer(
      samples: Float32List.fromList(_speakingBuffer),
      sampleRate: config.sampleRate,
      channels: 1,
    );

    _speakingBuffer.clear();
    _consecutiveSpeechFrames = 0;
    _consecutiveSilenceFrames = 0;
    _setState(SegmenterState.idle, reason: 'consumed');
    _finalizedUtteranceCount++;

    return buffer;
  }

  /// Finalize the stream: emit whatever is still buffered as an utterance.
  ///
  /// Call this once when the audio source stops (end of stream) so speech
  /// that never reached the silence or max-duration threshold is not lost.
  ///
  /// Idempotent — safe to call more than once. After the first call the
  /// segmenter is closed: [addBytes] and [addSamples] ignore input until
  /// [reset] is called.
  ///
  /// Sub-frame tails still sitting in the accumulators are processed as a
  /// final partial frame, so no samples are dropped and none are duplicated
  /// (a sample lives in exactly one accumulator).
  void flush() {
    if (_closed) return;
    _closed = true;

    // Drain leftovers so the tail of the stream is not lost.
    if (_sampleAccum.isNotEmpty) {
      final tail = Float32List.fromList(_sampleAccum);
      _sampleAccum.clear();
      _processFrame(tail);
    }
    if (_byteAccum.length >= 2) {
      final tail = _int16BytesToFloat32(_byteAccum);
      _byteAccum.clear();
      _processFrame(tail);
    }
    _byteAccum.clear();

    // Only an in-progress utterance needs finalizing. If the state machine
    // already emitted one (sustained silence or max duration), the caller
    // still has to consume it — flushing again would duplicate it.
    if (_state != SegmenterState.speaking) return;
    if (_speakingBuffer.isEmpty) return;

    _trimTrailingSilence();
    if (_speakingBuffer.isEmpty) return;

    _setState(SegmenterState.utteranceReady, reason: 'stream flushed');
  }

  /// Discard any in-progress utterance and return to [SegmenterState.idle].
  ///
  /// Also resets all counters and diagnostics.
  void reset() {
    _byteAccum.clear();
    _sampleAccum.clear();
    _preBuffer.clear();
    _speakingBuffer.clear();
    _consecutiveSpeechFrames = 0;
    _consecutiveSilenceFrames = 0;
    _currentRms = 0.0;
    _currentPeak = 0.0;
    _isSpeechDetected = false;
    _totalSamples = 0;
    _finalizedUtteranceCount = 0;
    _state = SegmenterState.idle;
    _closed = false;
  }

  // -------------------------------------------------------------------------
  // State machine
  // -------------------------------------------------------------------------

  void _processFrame(Float32List frame) {
    _totalSamples += frame.length;
    _currentRms = EnergyVad.computeRms(frame);
    _currentPeak = EnergyVad.computePeak(frame);
    _isSpeechDetected = _vad.isSpeech(frame);

    switch (_state) {
      case SegmenterState.idle:
        _handleIdle(frame);
      case SegmenterState.speaking:
        _handleSpeaking(frame);
      case SegmenterState.utteranceReady:
        // Frozen: caller must consume before we accept more audio.
        // Silently drop frames so the microphone stream does not block.
        break;
    }
  }

  void _handleIdle(Float32List frame) {
    // Keep rolling pre-speech padding ring buffer.
    _addToPreBuffer(frame);

    if (_isSpeechDetected) {
      _consecutiveSpeechFrames++;
      if (_consecutiveSpeechFrames >= config.consecutiveSpeechFrames) {
        // Enough consecutive speech → transition to SPEAKING.
        _consecutiveSilenceFrames = 0;
        // Prepend buffered pre-speech padding.
        _speakingBuffer.addAll(_preBuffer);
        _preBuffer.clear();
        _setState(SegmenterState.speaking, reason: 'speech onset');
      }
    } else {
      _consecutiveSpeechFrames = 0;
    }
  }

  void _handleSpeaking(Float32List frame) {
    // Only append to buffer if within the max utterance length.
    if (_speakingBuffer.length < config.maxUtteranceSamples) {
      _speakingBuffer.addAll(frame);
    }

    // E2: Force finalization when the buffer reaches the maximum utterance
    // duration. This prevents unbounded utterances (e.g. 14+ second runs)
    // that produce poor ASR quality and slow inference.
    // Uses sample count rather than wall-clock time so it is independent of
    // processing delays.
    if (_speakingBuffer.length >= config.maxUtteranceSamples) {
      _setState(
        SegmenterState.utteranceReady,
        reason: 'max duration reached',
      );
      return;
    }

    if (_isSpeechDetected) {
      _consecutiveSilenceFrames = 0;
    } else {
      _consecutiveSilenceFrames++;
      if (_consecutiveSilenceFrames >= config.consecutiveSilenceFrames) {
        // Sustained silence → finalize utterance.
        // The last N silence frames are already in _speakingBuffer and act
        // as natural post-speech padding.  Trim to keep at most
        // postSpeechPaddingSamples of trailing silence.
        _trimTrailingSilence();
        _setState(SegmenterState.utteranceReady, reason: 'sustained silence');
      }
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  void _addToPreBuffer(Float32List frame) {
    for (final s in frame) {
      _preBuffer.addLast(s);
    }
    // Trim to capacity.
    while (_preBuffer.length > config.preSpeechPaddingSamples) {
      _preBuffer.removeFirst();
    }
  }

  /// Trim trailing silence from [_speakingBuffer] to at most
  /// [VadConfig.postSpeechPaddingSamples].
  ///
  /// The consecutive silence frames already collected represent more than
  /// endSilenceDurationMs; we keep only postSpeechPaddingMs worth.
  void _trimTrailingSilence() {
    final silenceSamplesCollected =
        _consecutiveSilenceFrames * config.samplesPerFrame;
    final keepSilence = config.postSpeechPaddingSamples;
    final excessSilence = silenceSamplesCollected - keepSilence;
    if (excessSilence > 0 && _speakingBuffer.length > excessSilence) {
      _speakingBuffer.removeRange(
        _speakingBuffer.length - excessSilence,
        _speakingBuffer.length,
      );
    }
  }

  void _setState(SegmenterState next, {required String reason}) {
    if (_state == next) return;
    debugPrint(
      '[VAD] $_state → $next | reason=$reason '
      'rms=${_currentRms.toStringAsFixed(4)} '
      'samples=${_speakingBuffer.length}',
    );
    _state = next;
  }

  /// Convert a list of int16 little-endian bytes to a Float32List.
  ///
  /// Normalizes by dividing by 32768.0 to obtain ±1.0 range.
  static Float32List _int16BytesToFloat32(List<int> bytes) {
    final count = bytes.length ~/ 2;
    final result = Float32List(count);
    for (int i = 0; i < count; i++) {
      final lo = bytes[i * 2] & 0xFF;
      final hi = bytes[i * 2 + 1] & 0xFF;
      // Reconstruct signed int16.
      int s16 = (hi << 8) | lo;
      if (s16 >= 0x8000) s16 -= 0x10000;
      result[i] = s16 / 32768.0;
    }
    return result;
  }
}
