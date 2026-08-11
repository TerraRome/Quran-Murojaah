/// streaming_record_audio_recorder.dart
///
/// Production [StreamingAudioRecorder] implementation backed by the `record`
/// package's [AudioRecorder.startStream].
///
/// Unlike [RecordAudioRecorder] (which collects all chunks internally and
/// only returns them on [stop]), this class exposes a live [audioStream] of
/// raw int16 LE PCM bytes so that [MurojaahRecitationSession] can feed the
/// VAD/segmenter incrementally, one chunk at a time.
///
/// Configuration (must match AudioPreprocessor / ASR model):
///   - Sample rate : 16 000 Hz
///   - Channels    : 1 (mono)
///   - Encoding    : PCM 16-bit signed little-endian
///   - Android src : voiceRecognition (low-latency, noise-reduced)
///
/// Lifecycle:
/// ```
/// requestPermission() → true
///     ↓
/// initialize()
///     ↓
/// start()                ← audioStream begins emitting chunks
///     ↓
/// ... MurojaahRecitationSession reads audioStream ...
///     ↓
/// stop() → MurojaahAudioBuffer (all collected chunks concatenated)
///     ↓
/// dispose()
/// ```
///
/// [start] and [stop] may be called multiple times on the same instance.
/// [initialize] must be called once before [start].
/// [dispose] must be called when the recorder is no longer needed.
///
/// PLATFORM NOTE: [audioStream] and [stop] rely on
/// [AudioRecorder.startStream], which requires Android microphone permission
/// and the `record` native plugin. These cannot be exercised in unit tests
/// without a real device or integration-test harness.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../application/murojaah_recitation_session.dart';
import 'murojaah_audio_buffer.dart';
import 'murojaah_audio_recorder.dart';

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

/// [StreamingAudioRecorder] backed by the `record` package.
///
/// Callers (i.e. [MurojaahRecitationSession]) subscribe to [audioStream]
/// to receive live PCM bytes while the recorder is running.  On [stop], the
/// accumulated chunks are converted to a [MurojaahAudioBuffer] — the same
/// int16 LE → float32 conversion used by [RecordAudioRecorder].
class StreamingRecordAudioRecorder implements StreamingAudioRecorder {
  // ── Constants ──────────────────────────────────────────────────────────────

  static const int _sampleRate = 16000;
  static const int _channels   = 1;

  // ── State ──────────────────────────────────────────────────────────────────

  final AudioRecorder _recorder = AudioRecorder();

  bool _initialized = false;
  bool _recording   = false;
  bool _disposed    = false;

  /// Subscription to the raw platform PCM stream while recording.
  StreamSubscription<Uint8List>? _platformSub;

  /// All chunks received during the current recording, for [stop].
  final List<Uint8List> _chunks = [];

  /// Broadcast controller that exposes chunks to [MurojaahRecitationSession].
  ///
  /// A broadcast controller is used so that multiple subscribers (e.g. the
  /// session and a diagnostic UI) can listen without coordination.
  /// The controller is recreated on each [start] so subscribers from a
  /// previous session never receive stale audio.
  StreamController<Uint8List>? _controller;

  // ── StreamingAudioRecorder ─────────────────────────────────────────────────

  /// Live broadcast stream of raw int16 LE PCM bytes at 16 kHz mono.
  ///
  /// Emits chunks continuously between [start] and [stop].
  /// Returns an empty (closed) stream when not recording.
  ///
  /// IMPORTANT: subscribe *before* calling [start] to avoid dropping the
  /// first chunks (stream is already open when [start] completes).
  @override
  Stream<Uint8List> get audioStream {
    final ctrl = _controller;
    if (ctrl == null || ctrl.isClosed) return const Stream.empty();
    return ctrl.stream;
  }

  // ── MurojaahAudioRecorder ──────────────────────────────────────────────────

  @override
  Future<bool> requestPermission() async {
    _assertNotDisposed();
    return _recorder.hasPermission();
  }

  @override
  Future<void> initialize() async {
    _assertNotDisposed();
    // The `record` package requires no explicit initialization step beyond
    // construction.  We mark initialized here for lifecycle enforcement.
    _initialized = true;
  }

  /// Start streaming audio from the microphone.
  ///
  /// Opens a fresh broadcast [StreamController] and subscribes to the
  /// underlying platform stream.  Each incoming chunk is:
  ///   1. Forwarded to [audioStream] for live consumers.
  ///   2. Appended to [_chunks] so [stop] can reconstruct a full buffer.
  ///
  /// Throws [StateError] if:
  ///   - not initialized
  ///   - already recording
  ///   - microphone permission denied
  @override
  Future<void> start() async {
    _assertNotDisposed();
    if (!_initialized) {
      throw StateError(
        'StreamingRecordAudioRecorder: initialize() must be called before start()',
      );
    }
    if (_recording) {
      throw StateError('StreamingRecordAudioRecorder: already recording');
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw StateError(
        'StreamingRecordAudioRecorder: microphone permission denied. '
        'Call requestPermission() first and ensure the user grants access.',
      );
    }

    // Fresh controller for this recording session.
    _chunks.clear();
    _controller = StreamController<Uint8List>.broadcast();

    const config = RecordConfig(
      encoder:     AudioEncoder.pcm16bits,
      sampleRate:  _sampleRate,
      numChannels: _channels,
      androidConfig: AndroidRecordConfig(
        audioSource: AndroidAudioSource.voiceRecognition,
      ),
    );

    final platformStream = await _recorder.startStream(config);

    _platformSub = platformStream.listen(
      (Uint8List chunk) {
        if (_disposed || !_recording) return;
        _chunks.add(chunk);
        // Forward to live consumers if the controller is still open.
        if (!(_controller?.isClosed ?? true)) {
          _controller!.add(chunk);
        }
      },
      onError: (Object error, StackTrace stack) {
        // Surface the error on the broadcast stream so the session can react.
        if (!(_controller?.isClosed ?? true)) {
          _controller!.addError(error, stack);
        }
      },
      onDone: () {
        // Platform stream closed (e.g. after stop).  Close our controller
        // so subscribers know no more chunks are coming.
        _controller?.close();
      },
    );

    _recording = true;
  }

  /// Stop capturing and return all accumulated audio as a [MurojaahAudioBuffer].
  ///
  /// Closes [audioStream] so subscribers receive a done event.
  /// The returned buffer contains the full recording as normalized float32
  /// samples, identical in format to [RecordAudioRecorder.stop].
  ///
  /// Throws [StateError] if not currently recording.
  @override
  Future<MurojaahAudioBuffer> stop() async {
    _assertNotDisposed();
    if (!_recording) {
      throw StateError('StreamingRecordAudioRecorder: not currently recording');
    }

    // Stop the platform recorder first.  This triggers the platform stream's
    // onDone callback which closes our broadcast controller.
    await _recorder.stop();
    await _platformSub?.cancel();
    _platformSub = null;
    _recording = false;

    // Ensure controller is closed even if onDone did not fire synchronously.
    await _controller?.close();
    _controller = null;

    // Concatenate all received chunks into a single contiguous buffer.
    final totalBytes = _chunks.fold<int>(0, (sum, c) => sum + c.length);
    final allBytes   = Uint8List(totalBytes);
    int offset = 0;
    for (final chunk in _chunks) {
      allBytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    _chunks.clear();

    // Convert int16 LE → normalized float32 [-1.0, 1.0].
    // Each sample is 2 bytes, little-endian, signed.
    final nSamples = allBytes.length ~/ 2;
    final samples  = Float32List(nSamples);
    final bd       = allBytes.buffer.asByteData();
    for (int i = 0; i < nSamples; i++) {
      final int16val = bd.getInt16(i * 2, Endian.little);
      samples[i] = int16val / 32768.0;
    }

    return MurojaahAudioBuffer(
      samples:    samples,
      sampleRate: _sampleRate,
      channels:   _channels,
    );
  }

  /// Release all native resources.
  ///
  /// Safe to call while recording — stops recording first.
  /// Closes [audioStream] if still open.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    if (_recording) {
      _recording = false;
      // Best-effort stop — ignore errors during disposal.
      await _recorder.stop().catchError((Object _) => null);
      await _platformSub?.cancel();
    }
    _platformSub = null;

    await _controller?.close();
    _controller = null;

    _chunks.clear();
    // ignore: unawaited_futures
    _recorder.dispose();
  }

  @override
  bool get isRecording => _recording;

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('StreamingRecordAudioRecorder has been disposed');
    }
  }
}
