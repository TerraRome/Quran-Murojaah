/// quran_onnx_recognizer.dart
///
/// ONNX-backed implementation of [QuranAsrEngine].
///
/// Loads model_int8.onnx from Flutter assets and runs inference on a
/// 16-bit PCM WAV buffer or raw float32 PCM samples.  Precomputes the
/// Hann window and mel filterbank once on first use and reuses them.
///
/// Public API:
///   transcribeWav(Uint8List)          — existing; parses WAV then runs ONNX
///   transcribeSamples(Float32List)    — new; skips WAV parse, runs ONNX directly
///
/// Both paths share the same ONNX execution + CTC/BPE decode logic via the
/// private [_runOnnxAndDecode] method.
library quran_onnx_recognizer;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'audio_preprocessor.dart';
import 'quran_asr_result.dart';
import 'quran_onnx_model.dart';
import 'token_decoder.dart';

/// ONNX Runtime implementation of [QuranAsrEngine].
class QuranOnnxRecognizer implements QuranAsrEngine {
  static const String _modelAsset = 'assets/models/model_int8.onnx';
  static const String _vocabAsset = 'assets/models/tokenizer_vocab.json';

  // ONNX model input names (confirmed from Python POC + model inspection)
  static const String _inputAudioSignal = 'audio_signal';
  static const String _inputLength      = 'length';

  final OnnxRuntime _ort = OnnxRuntime();

  OrtSession? _session;
  Vocabulary?  _vocab;

  // Precomputed DSP state — built once, reused across calls
  Float32List? _hannWindow;
  Float32List? _melFilterbank;

  int _modelLoadMs = 0;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  /// Pre-load the ONNX session and vocabulary.  Optional — eliminates
  /// first-call latency by warming up the session ahead of time.
  Future<void> warmUp() async {
    await _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    if (_session != null && _vocab != null) return;

    final sw = Stopwatch()..start();

    // Load vocabulary JSON from asset
    if (_vocab == null) {
      final jsonStr = await rootBundle.loadString(_vocabAsset);
      final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
      _vocab = TokenDecoder.buildVocabulary(jsonMap);
    }

    // Load ONNX session from asset (extracted to temp file internally)
    if (_session == null) {
      _session = await _ort.createSessionFromAsset(
        _modelAsset,
        options: OrtSessionOptions(
          intraOpNumThreads: 1,
          interOpNumThreads: 1,
        ),
      );
    }

    // Precompute DSP state (cheap, but done once)
    _hannWindow    ??= AudioPreprocessor.buildHannWindow();
    _melFilterbank ??= AudioPreprocessor.buildMelFilterbank();

    sw.stop();
    _modelLoadMs = sw.elapsedMilliseconds;
  }

  // -------------------------------------------------------------------------
  // Public inference API
  // -------------------------------------------------------------------------

  /// Transcribe a raw 16-bit PCM WAV [Uint8List].
  ///
  /// Parses the WAV header to extract float32 samples, computes the log-mel
  /// spectrogram, runs the ONNX forward pass, and CTC/BPE-decodes the output.
  ///
  /// Existing callers are unaffected — behavior is identical to before.
  @override
  Future<AsrInferenceResult> transcribeWav(Uint8List wavBytes) async {
    await _ensureLoaded();

    final preprocessSw = Stopwatch()..start();
    final audio = AudioPreprocessor.processWavBytes(
      bytes:         wavBytes,
      hannWindow:    _hannWindow,
      melFilterbank: _melFilterbank,
    );
    preprocessSw.stop();

    return _runOnnxAndDecode(audio, preprocessSw.elapsedMilliseconds);
  }

  /// Transcribe already-decoded normalized float32 PCM [samples].
  ///
  /// Use this path when audio has been captured live (e.g. via
  /// [RecordAudioRecorder]) to avoid a redundant WAV encode/decode round-trip.
  ///
  /// [samples] must be 16 kHz mono float32 normalized to [-1.0, 1.0].
  ///
  /// [durationSeconds] is used for RTF calculation in the returned result.
  /// Internally, duration is also derived from sample count / sample rate
  /// by [AudioPreprocessor], so this value does not affect inference.
  @override
  Future<AsrInferenceResult> transcribeSamples(
    Float32List samples, {
    required double durationSeconds,
  }) async {
    await _ensureLoaded();

    final preprocessSw = Stopwatch()..start();
    final audio = AudioPreprocessor.process(
      samples:       samples,
      hannWindow:    _hannWindow!,
      melFilterbank: _melFilterbank!,
    );
    preprocessSw.stop();

    return _runOnnxAndDecode(audio, preprocessSw.elapsedMilliseconds);
  }

  // -------------------------------------------------------------------------
  // Private: shared ONNX execution + decode
  // -------------------------------------------------------------------------

  /// Run the ONNX forward pass on a preprocessed [audio] spectrogram and
  /// CTC/BPE-decode the output logits to an Arabic transcript.
  ///
  /// Both [transcribeWav] and [transcribeSamples] delegate here so the ONNX
  /// session management, tensor construction, and decode logic live in one
  /// place.
  Future<AsrInferenceResult> _runOnnxAndDecode(
    PreprocessedAudio audio,
    int preprocessMs,
  ) async {
    final int T = audio.nFrames;

    // --- Build ONNX input tensors ---
    // audio_signal: float32, shape [1, 80, T]
    // OrtValue infers float32 from Float32List automatically.
    final audioInput = await OrtValue.fromList(
      audio.tensor,
      [1, AudioPreprocessor.nMels, T],
    );

    // length: int64, shape [1]
    // Pass Int64List so the library maps it to int64 (not int32).
    final lengthInput = await OrtValue.fromList(
      Int64List.fromList([T]),
      [1],
    );

    // --- Run ONNX inference ---
    final inferenceSw = Stopwatch()..start();
    final outputs = await _session!.run({
      _inputAudioSignal: audioInput,
      _inputLength:      lengthInput,
    });
    inferenceSw.stop();
    final inferenceMs = inferenceSw.elapsedMilliseconds;

    // Release input tensors immediately to avoid memory pressure
    await audioInput.dispose();
    await lengthInput.dispose();

    // --- Decode output ---
    final decodeSw = Stopwatch()..start();

    // Single output — take first entry regardless of key name
    final outputValue = outputs.values.first;

    // Shape e.g. [T, 1, vocabSize] or [1, T, vocabSize]
    final outputShape = outputValue.shape;
    final int vocabSize = outputShape.last;

    // asFlattenedList() returns a flat 1-D List<dynamic> in row-major order
    final flatLogits = await outputValue.asFlattenedList();
    await outputValue.dispose();

    final transcript = TokenDecoder.decodeLogits(
      logits:    flatLogits,
      vocabSize: vocabSize,
      vocab:     _vocab!,
    );

    decodeSw.stop();
    final decodeMs = decodeSw.elapsedMilliseconds;

    return AsrInferenceResult(
      transcript:           transcript,
      audioDurationSeconds: audio.durationSeconds,
      timings: AsrTimings(
        modelLoadMs:  _modelLoadMs,
        preprocessMs: preprocessMs,
        inferenceMs:  inferenceMs,
        decodeMs:     decodeMs,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Dispose
  // -------------------------------------------------------------------------

  @override
  Future<void> dispose() async {
    await _session?.close();
    _session = null;
    _vocab   = null;
  }
}
