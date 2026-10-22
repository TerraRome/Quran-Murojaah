import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:recite_quran/recite_quran.dart';

/// Lifecycle of the on-device recitation engine for one surah.
enum ReciteMurojaahStatus {
  idle,
  preparing,
  downloadingModel,
  ready,
  listening,
  error,
}

/// Mode ujian hafalan: lompatan tidak dimaafkan (auto re-anchor mati), sehingga
/// kata yang dilewati ditandai merah. Ditulis eksplisit walau saat ini sama
/// dengan default paket, supaya perubahan default tidak diam-diam melonggarkan
/// penilaian.
const _examConfig = TrackerConfig(
  enableAutoReanchor: false, // ignore: avoid_redundant_argument_values
  reanchorStallThreshold: 24, // ignore: avoid_redundant_argument_values
);

/// Thin facade over `recite_quran` for a single surah: loads the surah,
/// ensures the ASR model exists, and pipes microphone audio into the tracker.
class ReciteMurojaahService {
  ReciteMurojaahService({required this.surahNumber});

  final int surahNumber;

  final ValueNotifier<ReciteMurojaahStatus> status =
      ValueNotifier<ReciteMurojaahStatus>(ReciteMurojaahStatus.idle);
  final ValueNotifier<double> downloadProgress = ValueNotifier<double>(0);
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);

  final AudioProcessor _audio = AudioProcessor();
  ReciteQuran? _tracker;
  List<QuranVerse> _verses = const [];
  Future<void>? _initializing;
  bool _listening = false;
  bool _disposed = false;

  /// Surah verses in Uthmani script; empty until [initialize] completes.
  List<QuranVerse> get verses => _verses;

  /// Global word offset of each verse, plus a final sentinel:
  /// `wordAyahStarts[i] .. wordAyahStarts[i + 1]` are the tracker `wordId`s
  /// owned by `verses[i]`. Empty until [initialize] completes.
  List<int> get wordAyahStarts => _wordAyahStarts;
  List<int> _wordAyahStarts = const [];

  /// Phoneme string tiap kata global (0-based `wordId`) — bahan
  /// `LcsOmissionDetector`. Empty until [initialize] completes.
  List<String> get wordPhonemes => _wordPhonemes;
  List<String> _wordPhonemes = const [];

  /// Matched-word events from the tracker (broadcast).
  Stream<WordMatchedEvent> get wordEvents =>
      _tracker?.onWordMatched ?? const Stream<WordMatchedEvent>.empty();

  /// Live ASR transcript (broadcast).
  Stream<String> get transcript =>
      _tracker?.onTranscript ?? const Stream<String>.empty();

  /// Idempotent; safe to call repeatedly or to retry after a failure.
  Future<void> initialize() {
    if (_disposed) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      _setStatus(ReciteMurojaahStatus.preparing);
      final meta = QuranMetadataService();
      final repository = QuranRepository(meta);
      await repository.loadSurahAsync(surahNumber);
      // `uthmaniWords` dari dataset memakai glyph Private Use Area (font khusus
      // QCF) sehingga tampil sebagai kotak di font apa pun. `aya_text` adalah
      // Unicode Arab asli dengan jumlah kata identik — pakai itu untuk render.
      final ayaText = (meta.rawJson?['verses'] ?? meta.rawJson);
      List<String> uiWords(QuranVerse v) {
        final raw = ayaText is Map ? ayaText['${v.surah}:${v.ayah}'] : null;
        final text = raw is Map ? raw['aya_text'] as String? : null;
        if (text == null) return v.uthmaniWords;
        final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        return words.length == v.uthmaniWords.length ? words : v.uthmaniWords;
      }

      final downloader = ModelDownloader();
      if (!await downloader.isModelReady()) {
        _setStatus(ReciteMurojaahStatus.downloadingModel);
        final ok = await downloader.downloadAssets(
          onProgress: (p, _) => downloadProgress.value = p,
        );
        if (!ok) {
          _fail('Gagal mengunduh model bacaan. Periksa koneksi lalu coba lagi.');
          return;
        }
        if (_disposed) return;
      }

      final tracker = ReciteQuran(
        repository: repository,
        // Model tidak dibundel di APK; arahkan engine ke folder unduhan.
        engine: SherpaEngine(
          assetOverrideDir: await downloader.getModelDirectoryPath(),
        ),
        // ignore: avoid_redundant_argument_values
        config: _examConfig,
        isTajweed: false,
      );
      await tracker.initialize();
      tracker.setTargetSurah(surahNumber);

      if (_disposed) {
        tracker.dispose();
        return;
      }
      _tracker = tracker;
      _verses = repository.getSurah(surahNumber).map((v) {
        final w = uiWords(v);
        return v.copyWith(uthmaniWords: w, textUthmani: w.join(' '));
      }).toList();

      // Authoritative word→ayah mapping: the tracker indexes words by
      // `getSurahWords` (phoneme words), not by Uthmani whitespace tokens.
      final words = repository.getSurahWords(surahNumber);
      final starts = <int>[0];
      var expectedAyah = 1;
      for (var i = 0; i < words.length; i++) {
        while (expectedAyah < words[i].ayah) {
          starts.add(i);
          expectedAyah++;
        }
      }
      starts.add(words.length);
      _wordAyahStarts = List<int>.unmodifiable(starts);
      _wordPhonemes =
          List<String>.unmodifiable(words.map((w) => w.phoneme));

      _setStatus(ReciteMurojaahStatus.ready);
      _log('ready: surah=$surahNumber verses=${_verses.length}');
    } catch (e) {
      _fail('Gagal menyiapkan mesin murojaah: $e');
    }
  }

  Future<void> startListening() async {
    if (_disposed || _listening) return;
    await initialize();
    final tracker = _tracker;
    if (tracker == null || status.value == ReciteMurojaahStatus.error) return;

    if (!await _audio.hasPermission()) {
      _fail('Izin mikrofon ditolak');
      return;
    }
    if (_disposed) return;

    try {
      await _audio.start(
        onChunk: (chunk, isFinal) =>
            tracker.feedAudioChunk(chunk, isFinal: isFinal),
      );
    } catch (e) {
      _fail('Gagal membuka mikrofon: $e');
      return;
    }
    _listening = true;
    _setStatus(ReciteMurojaahStatus.listening);
  }

  Future<void> stopListening() async {
    if (!_listening) return;
    _listening = false;
    await _audio.stop();
    _tracker?.resetBuffer();
    if (!_disposed) _setStatus(ReciteMurojaahStatus.ready);
  }

  /// Stops audio, releases the tracker, and disposes notifiers. Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _listening = false;
    await _audio.stop();
    _tracker?.dispose();
    _tracker = null;
    _verses = const [];
    _wordPhonemes = const [];
    downloadProgress.dispose();
    errorMessage.dispose();
    status.dispose();
  }

  void _setStatus(ReciteMurojaahStatus next) {
    if (_disposed) return;
    if (next != ReciteMurojaahStatus.error) errorMessage.value = null;
    status.value = next;
  }

  void _fail(String message) {
    if (_disposed) return;
    _listening = false;
    // Allow a fresh initialize() after a setup failure (download/model errors).
    if (_tracker == null) _initializing = null;
    errorMessage.value = message;
    status.value = ReciteMurojaahStatus.error;
    _log(message);
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[ReciteMurojaahService] $message');
  }
}
