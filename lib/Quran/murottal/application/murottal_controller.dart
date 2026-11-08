import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/datasources/audio_local_datasource.dart';
import '../../data/datasources/equran_remote_datasource.dart';
import '../../data/models/surah_audio_model.dart';
import '../../domain/entities/qari.dart';
import '../../murottal/application/qari_store.dart';
import 'murottal_prefs_store.dart';
import 'repeat_sequencer.dart';

/// Cari nama & jumlah ayat surah (untuk lanjut otomatis ke surah berikutnya).
typedef SurahInfoResolver = ({String name, int totalAyat})? Function(
    int surahNumber);

/// Mode player murottal.
enum PlayerMode {
  /// Audio berjalan di background, kontrol via MiniPlayer bottom sheet.
  miniPlayer,

  /// Audio highlight ayat aktif secara inline di list ayat.
  inline,
}

/// State player murottal.
sealed class MurottalState {
  const MurottalState();
}

class MurottalIdle extends MurottalState {
  const MurottalIdle();
}

class MurottalLoading extends MurottalState {
  const MurottalLoading({required this.surahNumber, this.surahName = ''});
  final int surahNumber;
  final String surahName;
}

class MurottalPlaying extends MurottalState {
  const MurottalPlaying({
    required this.surahNumber,
    required this.surahName,
    required this.currentAyat,
    required this.totalAyat,
    required this.qari,
    required this.position,
    required this.duration,
    this.isFullSurah = false,
  });

  final int surahNumber;
  final String surahName;
  final int currentAyat;   // 0 = full surah mode
  final int totalAyat;
  final Qari qari;
  final Duration position;
  final Duration duration;
  final bool isFullSurah;

  MurottalPlaying copyWith({
    int? currentAyat,
    Duration? position,
    Duration? duration,
  }) =>
      MurottalPlaying(
        surahNumber: surahNumber,
        surahName: surahName,
        currentAyat: currentAyat ?? this.currentAyat,
        totalAyat: totalAyat,
        qari: qari,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        isFullSurah: isFullSurah,
      );
}

class MurottalPaused extends MurottalState {
  const MurottalPaused({
    required this.surahNumber,
    required this.surahName,
    required this.currentAyat,
    required this.totalAyat,
    required this.qari,
    required this.position,
    required this.duration,
    this.isFullSurah = false,
  });

  final int surahNumber;
  final String surahName;
  final int currentAyat;
  final int totalAyat;
  final Qari qari;
  final Duration position;
  final Duration duration;
  final bool isFullSurah;
}

class MurottalError extends MurottalState {
  const MurottalError(this.message);
  final String message;
}

/// Controller murottal — manajemen audio player dan state.
///
/// Mendukung dua mode: full surah dan per ayat.
/// Local-first: cek file lokal dulu, fallback ke stream jika belum didownload.
/// State management: [ValueNotifier].
class MurottalController extends ValueNotifier<MurottalState> {
  MurottalController({
    required EquranRemoteDataSource datasource,
    required QariStore qariStore,
    AudioLocalDataSource? localDataSource,
    AudioPlayer? player,
    MurottalPrefsStore prefsStore = const MurottalPrefsStore(),
    SurahInfoResolver? surahInfo,
  })  : _datasource = datasource,
        _qariStore = qariStore,
        _player = player ?? AudioPlayer(),
        _prefsStore = prefsStore,
        _surahInfo = surahInfo,
        super(const MurottalIdle()) {
    _listenToPlayer();
    prefsLoaded = _loadPrefs();
  }

  final MurottalPrefsStore _prefsStore;
  final SurahInfoResolver? _surahInfo;
  final RepeatSequencer _sequencer = RepeatSequencer();

  /// Selesai saat kecepatan & lanjut otomatis tersimpan sudah dimuat.
  late final Future<void> prefsLoaded;

  /// Kecepatan putar (BL-01), diingat antar sesi.
  final ValueNotifier<double> speed = ValueNotifier(1.0);

  /// Pengaturan ulang & jeda (BL-02..BL-04). Mode, jumlah, jeda disimpan;
  /// rentang ayat tidak (spesifik per surah).
  final ValueNotifier<RepeatSettings> repeat =
      ValueNotifier(const RepeatSettings());

  /// Lanjut otomatis ke surah berikutnya (BL-07), default aktif.
  bool autoNextSurah = true;

  Timer? _gapTimer;

  /// Sisa detik jeda antar ulangan (BL-04-1); null bila tidak sedang jeda.
  final ValueNotifier<int?> gapRemaining = ValueNotifier(null);

  /// Menunggu satu ayat selesai diputar ([playOnce], BL-08).
  Completer<bool>? _once;

  void _finishOnce(bool completed) {
    final c = _once;
    _once = null;
    if (c != null && !c.isCompleted) c.complete(completed);
  }

  /// Langkah yang menunggu jeda selesai; dijalankan saat resume bila di-pause.
  void Function()? _pending;

  Future<void> _loadPrefs() async {
    speed.value = await _prefsStore.loadSpeed();
    autoNextSurah = await _prefsStore.loadAutoNext();
    final saved = await _prefsStore.loadRepeat();
    // Jangan timpa bila pengguna sudah mengubah pengaturan sebelum prefs termuat.
    if (repeat.value == const RepeatSettings()) {
      repeat.value = saved;
      _sequencer
        ..settings = saved
        ..reset();
    }
    await _applySpeed();
  }

  Future<void> _applySpeed() async {
    try {
      await _player.setSpeed(speed.value);
    } catch (_) {}
  }

  /// Ubah kecepatan putar dan simpan.
  Future<void> setSpeed(double v) async {
    speed.value = v;
    await _prefsStore.saveSpeed(v);
    await _applySpeed();
  }

  /// Ubah pengaturan ulang; hitungan ulangan dimulai dari awal.
  void setRepeat(RepeatSettings s) {
    final inGap = _pending != null;
    _cancelGap();
    _sequencer
      ..settings = s
      ..reset();
    repeat.value = s;
    _prefsStore.saveRepeat(s);
    // Jeda yang dibatalkan tadi satu-satunya penyambung ke ulangan berikutnya;
    // tanpa ini player berhenti di ujung ayat. Bila sedang di-pause, resume()
    // yang melanjutkan.
    if (inGap && value is MurottalPlaying) _onCompleted();
  }

  Future<void> setAutoNextSurah(bool v) async {
    autoNextSurah = v;
    await _prefsStore.saveAutoNext(v);
  }

  void _cancelGap() {
    _stopGapTimer();
    _pending = null;
  }

  void _stopGapTimer() {
    _gapTimer?.cancel();
    _gapTimer = null;
    gapRemaining.value = null;
  }

  /// Lewati jeda antar ulangan dan langsung putar ulangan berikutnya.
  void skipGap() {
    final run = _pending;
    if (run == null || _gapTimer == null) return;
    _cancelGap();
    run();
  }

  final EquranRemoteDataSource _datasource;
  QariStore _qariStore;
  final AudioPlayer _player;

  /// Update qari store setelah SharedPreferences siap.
  /// Dipanggil dari page setelah async prefs init selesai.
  void updateQariStore(QariStore store) {
    _qariStore = store;
  }

  /// Cache audio model per surah (untuk lookup URL ayat).
  final Map<int, SurahAudioModel> _audioCache = {};

  void _listenToPlayer() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onCompleted();
      }
    });

    _player.positionStream.listen((position) {
      final current = value;
      if (current is MurottalPlaying) {
        value = current.copyWith(position: position);
      }
    });

    _player.durationStream.listen((duration) {
      final current = value;
      if (current is MurottalPlaying && duration != null) {
        value = current.copyWith(duration: duration);
      }
    });
  }

  void _onCompleted() {
    final current = value;
    if (current is! MurottalPlaying) return;
    if (_pending != null) return; // sedang jeda antar ulangan
    if (_once != null) {
      // Putar-sekali: tidak ada lanjut otomatis, pemanggil yang menentukan.
      value = const MurottalIdle();
      _finishOnce(true);
      return;
    }

    final step = _sequencer.onAyatCompleted(
      surah: current.surahNumber,
      ayat: current.currentAyat,
      totalAyat: current.totalAyat,
      isFullSurah: current.isFullSurah,
      autoNextSurah: autoNextSurah,
    );
    switch (step) {
      case StopPlayback():
        value = const MurottalIdle();
      case PlaySurah(:final surah):
        final info = _surahInfo?.call(surah);
        if (info == null) {
          value = const MurottalIdle();
          return;
        }
        _playAyatInternal(
          surahNumber: surah,
          surahName: info.name,
          ayatNumber: 1,
          totalAyat: info.totalAyat,
          isFullSurah: true,
        );
      case PlayAyat(:final ayat, :final gap):
        void run() {
          if (ayat == current.currentAyat) {
            _replay(current);
          } else {
            _playAyatInternal(
              surahNumber: current.surahNumber,
              surahName: current.surahName,
              ayatNumber: ayat,
              totalAyat: current.totalAyat,
              isFullSurah: current.isFullSurah,
            );
          }
        }

        if (gap == Duration.zero) {
          run();
        } else {
          _pending = run;
          var left = (gap.inMilliseconds / 1000).ceil();
          gapRemaining.value = left;
          _gapTimer = Timer.periodic(const Duration(seconds: 1), (_) {
            left--;
            if (left > 0) {
              gapRemaining.value = left;
              return;
            }
            _stopGapTimer();
            _pending = null;
            run();
          });
        }
    }
  }

  /// Pesan error ramah untuk pengguna; detail teknis hanya ke log.
  void _failLoad(Object e) {
    debugPrint('Murottal: gagal memuat audio: $e');
    value = const MurottalError(
        'Gagal memuat audio. Periksa koneksi internet, lalu coba lagi.');
  }

  /// Ulang ayat yang sama tanpa memuat ulang sumber audio.
  Future<void> _replay(MurottalPlaying current) async {
    try {
      await _player.seek(Duration.zero);
      value = current.copyWith(position: Duration.zero);
      await _player.play();
    } catch (e) {
      _failLoad(e);
    }
  }

  /// Putar full surah sebagai urutan per-ayat sehingga currentAyat selalu
  /// ter-update dan highlight/auto-scroll berfungsi.
  Future<void> playFullSurah({
    required int surahNumber,
    required String surahName,
    required int totalAyat,
  }) async {
    _sequencer.reset();
    final rep = repeat.value;
    // Mode rentang: mulai dari ayat awal rentang, bukan ayat 1.
    final first = rep.mode == RepeatKind.range
        ? rep.rangeStart.clamp(1, totalAyat)
        : 1;
    await _playAyatInternal(
      surahNumber: surahNumber,
      surahName: surahName,
      ayatNumber: first,
      totalAyat: totalAyat,
      isFullSurah: true,
    );
  }

  /// Putar satu ayat (mode per-ayat, isFullSurah = false).
  Future<void> playAyat({
    required int surahNumber,
    required String surahName,
    required int ayatNumber,
    required int totalAyat,
  }) async {
    _sequencer.reset();
    await _playAyatInternal(
      surahNumber: surahNumber,
      surahName: surahName,
      ayatNumber: ayatNumber,
      totalAyat: totalAyat,
      isFullSurah: false,
    );
  }

  /// Putar satu ayat tanpa ulang/lanjut otomatis (BL-08). Selesai dengan true
  /// saat audio habis; false bila gagal dimuat atau dihentikan ([stop]).
  Future<bool> playOnce({
    required int surahNumber,
    required String surahName,
    required int ayatNumber,
    required int totalAyat,
  }) async {
    _finishOnce(false);
    _sequencer.reset();
    final done = _once = Completer<bool>();
    unawaited(
      _playAyatInternal(
        surahNumber: surahNumber,
        surahName: surahName,
        ayatNumber: ayatNumber,
        totalAyat: totalAyat,
        isFullSurah: false,
      ).then((_) {
        if (value is MurottalError) _finishOnce(false);
      }),
    );
    return done.future;
  }

  /// Internal: muat & putar satu ayat dengan flag isFullSurah.
  Future<void> _playAyatInternal({
    required int surahNumber,
    required String surahName,
    required int ayatNumber,
    required int totalAyat,
    required bool isFullSurah,
  }) async {
    _cancelGap();
    final qari = _qariStore.getSelectedQari();
    value = MurottalLoading(surahNumber: surahNumber, surahName: surahName);

    try {
      final audioModel = await _getAudioModel(surahNumber);
      final ayatModel = audioModel.ayat
          .where((a) => a.nomorAyat == ayatNumber)
          .firstOrNull;
      if (ayatModel == null) throw const EquranApiException('Data ayat tidak ditemukan');

      final url = ayatModel.audioUrl(qari.id);
      if (url == null) throw const EquranApiException('URL audio ayat tidak ditemukan');

      await _player.setUrl(url);
      await _applySpeed();

      value = MurottalPlaying(
        surahNumber: surahNumber,
        surahName: surahName,
        currentAyat: ayatNumber,
        totalAyat: totalAyat,
        qari: qari,
        position: Duration.zero,
        duration: _player.duration ?? Duration.zero,
        isFullSurah: isFullSurah,
      );

      await _player.play();
    } on EquranApiException catch (e) {
      value = MurottalError(e.message);
    } catch (e) {
      _failLoad(e);
    }
  }

  /// Pause audio yang sedang berjalan.
  Future<void> pause() async {
    final current = value;
    if (current is! MurottalPlaying) return;
    _stopGapTimer();
    await _player.pause();
    value = MurottalPaused(
      surahNumber: current.surahNumber,
      surahName: current.surahName,
      currentAyat: current.currentAyat,
      totalAyat: current.totalAyat,
      qari: current.qari,
      position: current.position,
      duration: current.duration,
      isFullSurah: current.isFullSurah,
    );
  }

  /// Resume audio yang di-pause.
  Future<void> resume() async {
    final current = value;
    if (current is! MurottalPaused) return;
    final pending = _pending;
    if (pending != null) {
      // Jeda ulangan terputus oleh pause: lanjutkan ke langkah berikutnya.
      _pending = null;
      pending();
      return;
    }
    final atEnd = _player.processingState == ProcessingState.completed;
    // Sumber yang sudah selesai tidak bisa di-play() lagi: tentukan langkah
    // berikutnya dengan pengaturan ulang terbaru (jeda diubah saat di-pause).
    if (!atEnd) await _player.play();
    value = MurottalPlaying(
      surahNumber: current.surahNumber,
      surahName: current.surahName,
      currentAyat: current.currentAyat,
      totalAyat: current.totalAyat,
      qari: current.qari,
      position: current.position,
      duration: current.duration,
      isFullSurah: current.isFullSurah,
    );
    if (atEnd) _onCompleted();
  }

  /// Stop dan reset ke idle.
  Future<void> stop() async {
    _cancelGap();
    _finishOnce(false);
    await _player.stop();
    value = const MurottalIdle();
  }

  /// Seek ke posisi tertentu.
  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  /// Pindah ke ayat berikutnya (hanya mode per-ayat).
  Future<void> nextAyat() async {
    final current = value;
    if (current is! MurottalPlaying || current.isFullSurah) return;
    if (current.currentAyat >= current.totalAyat) return;
    await playAyat(
      surahNumber: current.surahNumber,
      surahName: current.surahName,
      ayatNumber: current.currentAyat + 1,
      totalAyat: current.totalAyat,
    );
  }

  /// Pindah ke ayat sebelumnya (hanya mode per-ayat).
  Future<void> prevAyat() async {
    final current = value;
    if (current is! MurottalPlaying || current.isFullSurah) return;
    if (current.currentAyat <= 1) return;
    await playAyat(
      surahNumber: current.surahNumber,
      surahName: current.surahName,
      ayatNumber: current.currentAyat - 1,
      totalAyat: current.totalAyat,
    );
  }

  /// Cek apakah ayat tertentu sedang diputar.
  bool isPlayingAyat(int surahNumber, int ayatNumber) {
    final current = value;
    if (current is! MurottalPlaying) return false;
    return current.surahNumber == surahNumber &&
        current.currentAyat == ayatNumber &&
        !current.isFullSurah;
  }

  Future<SurahAudioModel> _getAudioModel(int surahNumber) async {
    if (_audioCache.containsKey(surahNumber)) {
      return _audioCache[surahNumber]!;
    }
    final model = await _datasource.getSurahAudio(surahNumber);
    _audioCache[surahNumber] = model;
    return model;
  }

  @override
  void dispose() {
    _gapTimer?.cancel();
    _finishOnce(false);
    gapRemaining.dispose();
    speed.dispose();
    repeat.dispose();
    _player.dispose();
    super.dispose();
  }
}
