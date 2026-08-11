import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Pembicara ayat (TTS) — membacakan ayat yang benar saat user membutuhkan
/// bantuan setelah beberapa kali salah. Abstraksi agar mudah di-fake di test.
abstract class VerseSpeaker {
  /// Bacakan teks transliterasi Latin ayat (id-ID TTS, slow rate untuk murojaah).
  /// [onDone] dipanggil saat bacaan selesai/berhenti/error.
  Future<void> speak(String text, {void Function()? onDone});

  /// Hentikan bacaan.
  Future<void> stop();

  /// `true` bila layanan TTS sedang membacakan.
  bool get isSpeaking;

  void dispose();
}

/// Implementasi asli memakai plugin `flutter_tts`.
class FlutterTtsVerseSpeaker implements VerseSpeaker {
  final FlutterTts _tts = FlutterTts();
  bool _configured = false;
  bool _speaking = false;
  void Function()? _onDone;

  @override
  bool get isSpeaking => _speaking;

  Future<void> _configure() async {
    if (_configured) return;
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      _speaking = false;
      _onDone?.call();
    });
    _tts.setErrorHandler((dynamic _) {
      _speaking = false;
      _onDone?.call();
    });
    _tts.setCancelHandler(() {
      _speaking = false;
      _onDone?.call();
    });
    _configured = true;
  }

  @override
  Future<void> speak(String text, {void Function()? onDone}) async {
    await _configure();
    _onDone = null;
    await _tts.stop();
    _onDone = onDone;
    final result = await _tts.speak(text);
    _speaking = result == 1;
  }

  @override
  Future<void> stop() async {
    _speaking = false;
    await _tts.stop();
  }

  @override
  void dispose() {
    _tts.stop();
  }
}

/// Status sesi bantuan bacaan (TTS).
enum VerseSpeakerStatus { idle, speaking }

/// Wrapper [VerseSpeaker] berbasis ValueNotifier agar status bisa didengar UI.
class VerseSpeakerSession extends ValueNotifier<VerseSpeakerStatus> {
  VerseSpeakerSession(this._speaker) : super(VerseSpeakerStatus.idle);

  final VerseSpeaker _speaker;

  /// Bacakan teks transliterasi Latin lalu kembali ke idle saat selesai.
  Future<void> speak(String text) async {
    value = VerseSpeakerStatus.speaking;
    await _speaker.speak(text, onDone: markDone);
  }

  /// Dipanggil saat TTS selesai/berhenti (dari handler completion/error).
  void markDone() {
    if (value == VerseSpeakerStatus.speaking) {
      value = VerseSpeakerStatus.idle;
    }
  }

  Future<void> stop() async {
    await _speaker.stop();
    markDone();
  }

  @override
  void dispose() {
    _speaker.dispose();
    super.dispose();
  }
}
