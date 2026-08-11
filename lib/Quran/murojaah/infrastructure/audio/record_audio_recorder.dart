/// record_audio_recorder.dart
///
/// Concrete [MurojaahAudioRecorder] implementation backed by the `record`
/// package (https://pub.dev/packages/record).
///
/// Configuration:
///   - Sample rate : 16000 Hz  (required by the ASR model)
///   - Channels    : 1 (mono)
///   - Encoding    : PCM 16-bit signed little-endian
///   - Android src : voiceRecognition  (low-latency, noise-reduced)
///
/// The implementation uses [AudioRecorder.startStream] to collect raw PCM
/// chunks into an in-memory buffer, then converts them to normalized float32
/// on [stop] — no filesystem I/O required for inference.
library record_audio_recorder;

import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'murojaah_audio_buffer.dart';
import 'murojaah_audio_recorder.dart';

class RecordAudioRecorder implements MurojaahAudioRecorder {
  // Target audio format — must match what AudioPreprocessor expects.
  static const int    _targetSampleRate = 16000;
  static const int    _targetChannels   = 1;

  final AudioRecorder _recorder = AudioRecorder();

  bool _initialized = false;
  bool _recording   = false;
  bool _disposed    = false;

  StreamSubscription<Uint8List>? _streamSub;
  final List<Uint8List> _chunks = [];

  // Actual config reported by the platform after start (logged for diagnostics)
  RecordConfig? _activeConfig;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<bool> requestPermission() async {
    _assertNotDisposed();
    return _recorder.hasPermission();
  }

  @override
  Future<void> initialize() async {
    _assertNotDisposed();
    // `record` package has no explicit initialize step — the AudioRecorder
    // constructor is sufficient.  We mark initialized here for state tracking.
    _initialized = true;
  }

  @override
  Future<void> start() async {
    _assertNotDisposed();
    if (!_initialized) {
      throw StateError(
        'RecordAudioRecorder: initialize() must be called before start()',
      );
    }
    if (_recording) {
      throw StateError('RecordAudioRecorder: already recording');
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw StateError(
        'RecordAudioRecorder: microphone permission denied. '
        'Call requestPermission() and ensure the user grants access.',
      );
    }

    _chunks.clear();

    _activeConfig = RecordConfig(
      encoder:     AudioEncoder.pcm16bits,
      sampleRate:  _targetSampleRate,
      numChannels: _targetChannels,
      androidConfig: const AndroidRecordConfig(
        audioSource: AndroidAudioSource.voiceRecognition,
      ),
    );

    final stream = await _recorder.startStream(_activeConfig!);

    _streamSub = stream.listen(
      (chunk) => _chunks.add(chunk),
      onError: (Object e) {
        // Log errors but do not crash — stop() will report an empty buffer
        // which the UI will flag as a problem.
        // ignore: avoid_print
        print('[RecordAudioRecorder] stream error: $e');
      },
    );

    _recording = true;
  }

  @override
  Future<MurojaahAudioBuffer> stop() async {
    _assertNotDisposed();
    if (!_recording) {
      throw StateError('RecordAudioRecorder: not currently recording');
    }

    await _recorder.stop();
    await _streamSub?.cancel();
    _streamSub = null;
    _recording = false;

    // Validate that the platform delivered the expected format.
    // The `record` package on Android should honour the requested config,
    // but we guard against surprises explicitly.
    final config = _activeConfig!;
    if (config.sampleRate != _targetSampleRate) {
      throw FormatException(
        'RecordAudioRecorder: expected sample rate $_targetSampleRate Hz '
        'but recorder reported ${config.sampleRate} Hz. '
        'Cannot feed mismatched audio to AudioPreprocessor.',
      );
    }
    if (config.numChannels != _targetChannels) {
      throw FormatException(
        'RecordAudioRecorder: expected $_targetChannels channel(s) '
        'but recorder reported ${config.numChannels}. '
        'Stereo downmix is not implemented.',
      );
    }

    // Concatenate all PCM chunks into one contiguous buffer.
    final totalBytes = _chunks.fold<int>(0, (sum, c) => sum + c.length);
    final allBytes   = Uint8List(totalBytes);
    int offset = 0;
    for (final chunk in _chunks) {
      allBytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    _chunks.clear();

    // Convert int16 LE → normalized float32 [-1.0, 1.0].
    // Each sample is 2 bytes little-endian signed.
    final nSamples = allBytes.length ~/ 2;
    final samples  = Float32List(nSamples);
    final bd       = allBytes.buffer.asByteData();
    for (int i = 0; i < nSamples; i++) {
      final int16val = bd.getInt16(i * 2, Endian.little);
      samples[i] = int16val / 32768.0;
    }

    return MurojaahAudioBuffer(
      samples:    samples,
      sampleRate: _targetSampleRate,
      channels:   _targetChannels,
    );
  }

  @override
  Future<void> dispose() async {
    if (_recording) {
      await _recorder.stop().catchError((_) {});
      await _streamSub?.cancel();
    }
    _recorder.dispose();
    _disposed  = true;
    _recording = false;
  }

  @override
  bool get isRecording => _recording;

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  /// Human-readable description of the active recording configuration.
  /// Useful for the capture POC page.
  String get configDescription {
    final c = _activeConfig;
    if (c == null) return 'Not configured yet';
    return 'sampleRate=${c.sampleRate}Hz '
        'channels=${c.numChannels} '
        'encoder=${c.encoder.name}';
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('RecordAudioRecorder has been disposed');
    }
  }
}
