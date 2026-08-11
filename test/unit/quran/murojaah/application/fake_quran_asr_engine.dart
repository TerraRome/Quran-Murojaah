/// fake_quran_asr_engine.dart
///
/// Test double for [QuranAsrEngine].
///
/// Allows tests to:
///   - Configure the transcript returned per call.
///   - Track invocation count and arguments.
///   - Inject inference errors.
///   - Simulate async delay.
library fake_quran_asr_engine;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_portfolio/Quran/murojaah/infrastructure/asr/quran_asr_result.dart';
import 'package:flutter_portfolio/Quran/murojaah/infrastructure/asr/quran_onnx_model.dart';

/// Fake [QuranAsrEngine] for unit tests.
///
/// Does NOT load any ONNX model. All results are returned from the
/// configurable [transcriptQueue] or [defaultTranscript].
class FakeQuranAsrEngine implements QuranAsrEngine {
  FakeQuranAsrEngine({
    String defaultTranscript = '',
    this.inferenceDelayMs = 0,
  }) : defaultTranscript = defaultTranscript;

  // ── Configuration ─────────────────────────────────────────────────────────

  /// Transcript returned when [transcriptQueue] is empty.
  String defaultTranscript;

  /// Queue of transcripts to return in order. Each call pops the front.
  /// Falls back to [defaultTranscript] when empty.
  final List<String> transcriptQueue = [];

  /// If non-null, [transcribeSamples] throws this on the next call.
  /// Cleared after use.
  Exception? errorOnNextCall;

  /// Simulated async delay in milliseconds.
  int inferenceDelayMs;

  // ── Call tracking ─────────────────────────────────────────────────────────

  /// Number of times [transcribeSamples] was called.
  int transcribeSamplesCallCount = 0;

  /// All [Float32List] samples passed to [transcribeSamples], in order.
  final List<Float32List> capturedSamples = [];

  /// All [durationSeconds] values passed to [transcribeSamples], in order.
  final List<double> capturedDurations = [];

  /// Whether [dispose] was called.
  bool disposed = false;

  // ── QuranAsrEngine ────────────────────────────────────────────────────────

  /// Number of times [warmUp] was called.
  int warmUpCallCount = 0;

  /// If true, [warmUp] throws on the next call.
  bool throwOnWarmUp = false;

  @override
  Future<void> warmUp() async {
    warmUpCallCount++;
    if (throwOnWarmUp) throw Exception('warm-up failed');
  }

  @override
  Future<AsrInferenceResult> transcribeWav(Uint8List wavBytes) async {
    // Not used by MurojaahRecitationSession, but must be implemented.
    return _makeResult('', 0.0);
  }

  @override
  Future<AsrInferenceResult> transcribeSamples(
    Float32List samples, {
    required double durationSeconds,
  }) async {
    transcribeSamplesCallCount++;
    capturedSamples.add(Float32List.fromList(samples));
    capturedDurations.add(durationSeconds);

    if (inferenceDelayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: inferenceDelayMs));
    }

    if (errorOnNextCall != null) {
      final err = errorOnNextCall!;
      errorOnNextCall = null;
      throw err;
    }

    final transcript = transcriptQueue.isNotEmpty
        ? transcriptQueue.removeAt(0)
        : defaultTranscript;

    return _makeResult(transcript, durationSeconds);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  AsrInferenceResult _makeResult(String transcript, double durationSeconds) {
    return AsrInferenceResult(
      transcript: transcript,
      audioDurationSeconds: durationSeconds,
      timings: const AsrTimings(
        modelLoadMs: 0,
        preprocessMs: 1,
        inferenceMs: 1,
        decodeMs: 1,
      ),
    );
  }
}
