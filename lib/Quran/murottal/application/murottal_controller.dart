import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/datasources/audio_local_datasource.dart';
import '../../data/datasources/equran_remote_datasource.dart';
import '../../data/models/surah_audio_model.dart';
import '../../domain/entities/qari.dart';
import '../../murottal/application/qari_store.dart';

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
  const MurottalLoading({required this.surahNumber});
  final int surahNumber;
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
  })  : _datasource = datasource,
        _qariStore = qariStore,
        _player = player ?? AudioPlayer(),
        super(const MurottalIdle()) {
    _listenToPlayer();
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

    // Auto-advance ke ayat berikutnya — baik mode per-ayat maupun full-surah
    if (current.currentAyat < current.totalAyat) {
      _playAyatInternal(
        surahNumber: current.surahNumber,
        surahName: current.surahName,
        ayatNumber: current.currentAyat + 1,
        totalAyat: current.totalAyat,
        isFullSurah: current.isFullSurah,
      );
    } else {
      value = const MurottalIdle();
    }
  }

  /// Putar full surah sebagai urutan per-ayat sehingga currentAyat selalu
  /// ter-update dan highlight/auto-scroll berfungsi.
  Future<void> playFullSurah({
    required int surahNumber,
    required String surahName,
    required int totalAyat,
  }) async {
    await _playAyatInternal(
      surahNumber: surahNumber,
      surahName: surahName,
      ayatNumber: 1,
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
    await _playAyatInternal(
      surahNumber: surahNumber,
      surahName: surahName,
      ayatNumber: ayatNumber,
      totalAyat: totalAyat,
      isFullSurah: false,
    );
  }

  /// Internal: muat & putar satu ayat dengan flag isFullSurah.
  Future<void> _playAyatInternal({
    required int surahNumber,
    required String surahName,
    required int ayatNumber,
    required int totalAyat,
    required bool isFullSurah,
  }) async {
    final qari = _qariStore.getSelectedQari();
    value = MurottalLoading(surahNumber: surahNumber);

    try {
      final audioModel = await _getAudioModel(surahNumber);
      final ayatModel = audioModel.ayat
          .where((a) => a.nomorAyat == ayatNumber)
          .firstOrNull;
      if (ayatModel == null) throw const EquranApiException('Data ayat tidak ditemukan');

      final url = ayatModel.audioUrl(qari.id);
      if (url == null) throw const EquranApiException('URL audio ayat tidak ditemukan');

      await _player.setUrl(url);

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
      value = MurottalError('Gagal memuat audio: $e');
    }
  }

  /// Pause audio yang sedang berjalan.
  Future<void> pause() async {
    final current = value;
    if (current is! MurottalPlaying) return;
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
    await _player.play();
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
  }

  /// Stop dan reset ke idle.
  Future<void> stop() async {
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
    _player.dispose();
    super.dispose();
  }
}
