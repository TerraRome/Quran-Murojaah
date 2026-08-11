import 'package:flutter_portfolio/Quran/murojaah/application/speech_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSpeechRecognizer implements SpeechRecognizer {
  _FakeSpeechRecognizer({this.available = true});

  final bool available;
  void Function(RecognizedSpeech)? _onResult;
  void Function(String)? _onError;
  bool listenCalled = false;
  int stopCount = 0;

  void emit(RecognizedSpeech speech) => _onResult?.call(speech);
  void fail(String message) => _onError?.call(message);

  @override
  bool get isAvailable => available;

  @override
  Future<bool> get hasPermission async => available;

  @override
  Future<bool> initialize() async => available;

  @override
  void listen({
    required void Function(RecognizedSpeech speech) onResult,
    required void Function(String message) onError,
    void Function(String status)? onStatus,
  }) {
    listenCalled = true;
    _onResult = onResult;
    _onError = onError;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  void dispose() {}
}

void main() {
  test('start mengalir: initializing → listening', () async {
    final recognizer = _FakeSpeechRecognizer();
    final session = SpeechSession(recognizer);

    expect(session.value.status, SpeechRecognitionStatus.idle);

    final ok = await session.start();
    expect(ok, isTrue);
    expect(recognizer.listenCalled, isTrue);
    expect(session.value.status, SpeechRecognitionStatus.listening);
    expect(session.isListening, isTrue);

    session.dispose();
  });

  test('stop menandai recognized & mempertahankan transkrip', () async {
    final recognizer = _FakeSpeechRecognizer();
    final session = SpeechSession(recognizer);

    await session.start();
    recognizer.emit(const RecognizedSpeech(
      status: SpeechRecognitionStatus.listening,
      transcript: 'alhamdulillah',
    ));
    expect(session.value.transcript, 'alhamdulillah');

    await session.stop();
    expect(recognizer.stopCount, 1);
    expect(session.value.status, SpeechRecognitionStatus.recognized);
    expect(session.value.transcript, 'alhamdulillah');
    expect(session.isListening, isFalse);

    session.dispose();
  });

  test('initialize gagal → unavailable dan tidak mendengarkan', () async {
    final recognizer = _FakeSpeechRecognizer(available: false);
    final session = SpeechSession(recognizer);

    final ok = await session.start();
    expect(ok, isFalse);
    expect(session.value.status, SpeechRecognitionStatus.unavailable);
    expect(recognizer.listenCalled, isFalse);

    session.dispose();
  });

  test('clear mengembalikan ke idle & menghapus transkrip', () async {
    final recognizer = _FakeSpeechRecognizer();
    final session = SpeechSession(recognizer);

    await session.start();
    recognizer.emit(const RecognizedSpeech(
      status: SpeechRecognitionStatus.listening,
      transcript: 'bismillah',
    ));
    session.clear();

    expect(session.value.status, SpeechRecognitionStatus.idle);
    expect(session.value.transcript, isEmpty);

    session.dispose();
  });

  test('error saat listen menangkap pesan asli dari plugin', () async {
    final recognizer = _FakeSpeechRecognizer();
    final session = SpeechSession(recognizer);

    await session.start();
    recognizer.fail('error_not_found');

    expect(session.value.status, SpeechRecognitionStatus.error);
    expect(session.value.errorMessage, 'error_not_found');

    session.dispose();
  });
}
