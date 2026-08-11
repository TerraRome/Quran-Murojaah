/// murojaah_audio_recorder.dart
///
/// Abstract interface for microphone capture in the Murojaah ASR pipeline.
///
/// Concrete implementations:
///   - [RecordAudioRecorder]  — uses the `record` package (production)
///   - [FakeAudioRecorder]    — deterministic stub for unit tests
library murojaah_audio_recorder;

import 'dart:typed_data';

import 'murojaah_audio_buffer.dart';

export 'murojaah_audio_buffer.dart';

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

/// Microphone recorder lifecycle:
///
/// ```
/// requestPermission() → true
///     ↓
/// initialize()
///     ↓
/// start()           ← user taps Record
///     ↓
/// ... user recites ...
///     ↓
/// stop() → MurojaahAudioBuffer
///     ↓
/// dispose()
/// ```
///
/// [start] and [stop] may be called multiple times on the same instance.
/// [initialize] must be called once before [start].
/// [dispose] must be called when the recorder is no longer needed.
abstract interface class MurojaahAudioRecorder {
  /// Check and request microphone permission.
  ///
  /// Returns `true` if permission is granted, `false` otherwise.
  Future<bool> requestPermission();

  /// Prepare the recorder.  Must be called once before [start].
  Future<void> initialize();

  /// Start capturing audio from the microphone.
  ///
  /// Throws [StateError] if not initialized, or if already recording.
  Future<void> start();

  /// Stop capturing and return the accumulated audio buffer.
  ///
  /// Throws [StateError] if not currently recording.
  Future<MurojaahAudioBuffer> stop();

  /// Release all native resources.
  Future<void> dispose();

  /// Whether audio capture is currently active.
  bool get isRecording;
}

// ---------------------------------------------------------------------------
// Fake implementation for unit tests
// ---------------------------------------------------------------------------

/// In-memory stub that returns a pre-configured [MurojaahAudioBuffer] on
/// [stop].  Does not touch any platform channels.
class FakeAudioRecorder implements MurojaahAudioRecorder {
  bool _initialized = false;
  bool _recording   = false;
  bool _disposed    = false;

  final Float32List fakeSamples;
  final int         fakeSampleRate;
  final int         fakeChannels;
  final Object?     startError;

  FakeAudioRecorder({
    Float32List? fakeSamples,
    this.fakeSampleRate = 16000,
    this.fakeChannels   = 1,
    this.startError,
  }) : fakeSamples = fakeSamples ?? Float32List(16000);

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> initialize() async {
    if (_disposed) throw StateError('FakeAudioRecorder has been disposed');
    _initialized = true;
  }

  @override
  Future<void> start() async {
    if (_disposed)      throw StateError('FakeAudioRecorder has been disposed');
    if (!_initialized)  throw StateError('initialize() must be called before start()');
    if (_recording)     throw StateError('Already recording');
    if (startError != null) throw startError!;
    _recording = true;
  }

  @override
  Future<MurojaahAudioBuffer> stop() async {
    if (_disposed)   throw StateError('FakeAudioRecorder has been disposed');
    if (!_recording) throw StateError('Not currently recording');
    _recording = false;
    return MurojaahAudioBuffer(
      samples:    fakeSamples,
      sampleRate: fakeSampleRate,
      channels:   fakeChannels,
    );
  }

  @override
  Future<void> dispose() async {
    _disposed  = true;
    _recording = false;
  }

  @override
  bool get isRecording => _recording;
}
