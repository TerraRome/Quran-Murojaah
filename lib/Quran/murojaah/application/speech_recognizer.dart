import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Status siklus speech recognition (independen dari [MurojaahStatus]).
enum SpeechRecognitionStatus {
  /// Belum ada sesi; siap mendengarkan.
  idle,

  /// Sedang inisialisasi & meminta izin mikrofon.
  initializing,

  /// Mikrofon aktif, transkrip partial mengalir.
  listening,

  /// Hasil final telah diterima / dihentikan user.
  recognized,

  /// Fitur tidak tersedia (izin ditolak / tanpa dukungan STT).
  unavailable,

  /// Terjadi error saat recognition.
  error,
}

/// Ringkasan hasil speech recognition.
@immutable
class RecognizedSpeech {
  const RecognizedSpeech({
    this.status = SpeechRecognitionStatus.idle,
    this.transcript = '',
    this.errorMessage,
  });

  final SpeechRecognitionStatus status;
  final String transcript;

  /// Pesan error asli dari platform (untuk debugging / feedback yang jelas).
  final String? errorMessage;

  bool get isListening => status == SpeechRecognitionStatus.listening;

  RecognizedSpeech copyWith({
    SpeechRecognitionStatus? status,
    String? transcript,
    String? errorMessage,
  }) {
    return RecognizedSpeech(
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Abstraksi pengenal suara agar bisa di-fake di test.
abstract class SpeechRecognizer {
  /// `true` bila layanan STT tersedia setelah [initialize].
  bool get isAvailable;

  /// Apakah izin mikrofon sudah diberikan.
  Future<bool> get hasPermission;

  /// Inisialisasi & meminta izin mikrofon. `true` bila siap mendengarkan.
  Future<bool> initialize();

  /// Mulai mendengarkan. Hasil partial/final dikirim via [onResult],
  /// error via [onError]. Status layanan dipakai juga lewat [onStatus].
  void listen({
    required void Function(RecognizedSpeech speech) onResult,
    required void Function(String message) onError,
    void Function(String status)? onStatus,
  });

  /// Hentikan pendengaran & ambil hasil final.
  Future<void> stop();

  void dispose();
}

/// Implementasi asli memakai plugin `speech_to_text` (Milestone 4).
class SpeechToTextRecognizer implements SpeechRecognizer {
  SpeechToTextRecognizer({this.preferArabicLocale = true});

  final stt.SpeechToText _plugin = stt.SpeechToText();

  /// Bila `true`, coba gunakan locale Arab (mis. `ar-SA`) untuk mengenali
  /// bacaan Al-Quran alih-alih locale default device (yang mungkin Inggris).
  final bool preferArabicLocale;

  bool _initialized = false;
  String? _localeId;
  void Function(String message)? _onError;
  void Function(String status)? _onStatus;

  @override
  bool get isAvailable => _plugin.isAvailable;

  @override
  Future<bool> get hasPermission => _plugin.hasPermission;

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    final available = await _plugin.initialize(
      onStatus: (status) => _onStatus?.call(status),
      onError: (error) => _onError?.call(error.errorMsg),
    );
    _initialized = available;
    if (available && preferArabicLocale) {
      _localeId = await _resolveArabicLocale();
    }
    return available;
  }

  /// Pilih locale Arab dari daftar bahasa yang didukung recognizer device.
  /// Prioritas: `ar-SA` → `ar` → locale Arab pertama.
  /// Bila tidak ada di daftar (daftar on-device sering terbatas), fallback
  /// ke `ar-SA` karena recognition online Google mendukung Arab — sehingga
  /// bacaan tidak terdeteksi sebagai bahasa default device (mis. Inggris).
  Future<String?> _resolveArabicLocale() async {
    try {
      final locales = await _plugin
          .locales()
          .timeout(const Duration(seconds: 5), onTimeout: () => <stt.LocaleName>[]);
      if (locales.isNotEmpty) {
        final arabic = locales.where((l) => l.localeId.startsWith('ar'));
        if (arabic.isNotEmpty) {
          final preferred = arabic.firstWhere(
            (l) => l.localeId == 'ar-SA' || l.localeId == 'ar',
            orElse: () => arabic.first,
          );
          return preferred.localeId;
        }
      }
    } catch (_) {}
    return preferArabicLocale ? 'ar-SA' : null;
  }

  @override
  void listen({
    required void Function(RecognizedSpeech speech) onResult,
    required void Function(String message) onError,
    void Function(String status)? onStatus,
  }) {
    _onError = onError;
    _onStatus = onStatus;
    _plugin.listen(
      onResult: (result) {
        onResult(
          RecognizedSpeech(
            status: result.finalResult
                ? SpeechRecognitionStatus.recognized
                : SpeechRecognitionStatus.listening,
            transcript: result.recognizedWords,
          ),
        );
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        localeId: _localeId,
      ),
    );
  }

  @override
  Future<void> stop() => _plugin.stop();

  @override
  void dispose() {
    _plugin.cancel();
  }
}

/// ValueNotifier sesi speech (state + transkrip), di-drive oleh [SpeechRecognizer].
class SpeechSession extends ValueNotifier<RecognizedSpeech> {
  SpeechSession(this._recognizer) : super(const RecognizedSpeech());

  final SpeechRecognizer _recognizer;

  bool get isListening => value.isListening;

  /// Inisialisasi, minta izin, lalu mulai mendengarkan.
  /// Mengembalikan `false` bila fitur tidak tersedia / izin ditolak.
  Future<bool> start() async {
    value = const RecognizedSpeech(status: SpeechRecognitionStatus.initializing);
    final available = await _recognizer.initialize();
    if (!available || !await _recognizer.hasPermission) {
      value = const RecognizedSpeech(status: SpeechRecognitionStatus.unavailable);
      return false;
    }
    // Beri waktu platform menutup sesi sebelumnya sebelum listen lagi.
    // Plugin speech_to_text di Android perlu cooldown setelah stop()
    // agar tidak kehilangan audio pada sesi ke-2 dan seterusnya.
    await Future.delayed(const Duration(milliseconds: 350));
    _recognizer.listen(
      onResult: (speech) => value = speech,
      onError: (message) => value = RecognizedSpeech(
        status: SpeechRecognitionStatus.error,
        errorMessage: message,
      ),
    );
    value = const RecognizedSpeech(status: SpeechRecognitionStatus.listening);
    return true;
  }

  /// Hentikan pendengaran; transkrip terakhir dipertahankan.
  Future<void> stop() async {
    await _recognizer.stop();
    value = RecognizedSpeech(
      status: SpeechRecognitionStatus.recognized,
      transcript: value.transcript,
    );
  }

  /// Bersihkan sesi kembali ke idle (transkrip dihapus).
  void clear() {
    value = const RecognizedSpeech();
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }
}
