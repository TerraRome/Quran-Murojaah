/// FakeSpeechRecognizer — test-only implementation of [SpeechRecognizer].
///
/// Allows tests to drive recognition events programmatically without a
/// microphone or platform plugin:
///
///   final fake = FakeSpeechRecognizer();
///   await fake.initialize();
///
///   // emit an interim result (should NOT trigger matching)
///   fake.emitPartial('وَالْقُرْآن');
///
///   // emit a final result (should trigger matching)
///   fake.emitFinal('وَالْقُرْآنِ الْحَكِيمِ');
///
///   // simulate an error
///   fake.emitError('mic_unavailable');
///
/// Usage notes:
/// - [isAvailable] defaults to true; set to false to simulate unavailability.
/// - [hasPermission] defaults to true; set to false to simulate denial.
/// - [initialize] always succeeds when [isAvailable] is true.
/// - Captured callbacks are set by the first [listen] call and cleared by
///   [dispose].

import 'package:flutter_portfolio/Quran/murojaah/application/speech_recognizer.dart';

class FakeSpeechRecognizer implements SpeechRecognizer {
  FakeSpeechRecognizer({
    bool available = true,
    bool permission = true,
  })  : _available = available,
        _permission = permission;

  bool _available;
  final bool _permission;
  bool _initialized = false;
  bool _listening = false;
  bool _disposed = false;

  void Function(RecognizedSpeech)? _onResult;
  void Function(String)? _onError;
  void Function(String)? _onStatus;

  // ─── SpeechRecognizer interface ───────────────────────────────────────────

  @override
  bool get isAvailable => _available;

  @override
  Future<bool> get hasPermission async => _permission;

  @override
  Future<bool> initialize() async {
    if (!_available) return false;
    _initialized = true;
    return true;
  }

  @override
  void listen({
    required void Function(RecognizedSpeech speech) onResult,
    required void Function(String message) onError,
    void Function(String status)? onStatus,
  }) {
    assert(_initialized, 'Must call initialize() before listen()');
    assert(!_disposed, 'Cannot listen on a disposed recognizer');
    _onResult = onResult;
    _onError = onError;
    _onStatus = onStatus;
    _listening = true;
    _onStatus?.call('listening');
  }

  @override
  Future<void> stop() async {
    _listening = false;
    _onStatus?.call('done');
  }

  @override
  void dispose() {
    _disposed = true;
    _listening = false;
    _onResult = null;
    _onError = null;
    _onStatus = null;
  }

  // ─── Test helpers ─────────────────────────────────────────────────────────

  /// Emit an interim (non-final) partial transcript.
  /// The controller must NOT advance the verse on partial results.
  void emitPartial(String transcript) {
    assert(_listening, 'Not listening — call listen() first');
    _onResult?.call(RecognizedSpeech(
      status: SpeechRecognitionStatus.listening,
      transcript: transcript,
    ));
  }

  /// Emit a final recognized transcript.
  /// The controller SHOULD run matching and potentially advance the verse.
  void emitFinal(String transcript) {
    assert(_listening, 'Not listening — call listen() first');
    _onResult?.call(RecognizedSpeech(
      status: SpeechRecognitionStatus.recognized,
      transcript: transcript,
    ));
  }

  /// Emit a recognition error.
  void emitError(String message) {
    _onError?.call(message);
  }

  /// Simulate the service becoming unavailable after initialization.
  void setUnavailable() => _available = false;

  bool get isListening => _listening;
  bool get isInitialized => _initialized;
  bool get isDisposed => _disposed;
}
