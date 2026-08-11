import 'package:flutter/foundation.dart';

import '../../data/datasources/equran_remote_datasource.dart';
import '../../domain/entities/tafsir.dart';

/// State untuk TafsirController.
sealed class TafsirState {
  const TafsirState();
}

class TafsirIdle extends TafsirState {
  const TafsirIdle();
}

class TafsirLoading extends TafsirState {
  const TafsirLoading();
}

class TafsirLoaded extends TafsirState {
  const TafsirLoaded({
    required this.surahNumber,
    required this.tafsirList,
    required this.activeAyat,
  });

  final int surahNumber;
  final List<Tafsir> tafsirList;
  final int activeAyat;

  /// Ambil tafsir untuk ayat aktif. Null jika tidak ditemukan.
  Tafsir? get activeTafsir =>
      tafsirList.where((t) => t.ayat == activeAyat).firstOrNull;

  TafsirLoaded copyWith({int? activeAyat}) => TafsirLoaded(
        surahNumber: surahNumber,
        tafsirList: tafsirList,
        activeAyat: activeAyat ?? this.activeAyat,
      );
}

class TafsirError extends TafsirState {
  const TafsirError(this.message);
  final String message;
}

/// Controller tafsir — fetch dari API equran.id + cache in-memory per surah.
///
/// State management: [ValueNotifier]. Cache sederhana: Map<surahNumber, List<Tafsir>>.
/// Fetch hanya dilakukan sekali per surah selama session (in-memory cache).
class TafsirController extends ValueNotifier<TafsirState> {
  TafsirController({required EquranRemoteDataSource datasource})
      : _datasource = datasource,
        super(const TafsirIdle());

  final EquranRemoteDataSource _datasource;

  /// Cache in-memory: surahNumber → List<Tafsir>.
  final Map<int, List<Tafsir>> _cache = {};

  /// Buka bottom sheet tafsir untuk surah + ayat tertentu.
  /// Jika data sudah di-cache, langsung set state tanpa fetch.
  Future<void> open(int surahNumber, int ayatNumber) async {
    if (_cache.containsKey(surahNumber)) {
      value = TafsirLoaded(
        surahNumber: surahNumber,
        tafsirList: _cache[surahNumber]!,
        activeAyat: ayatNumber,
      );
      return;
    }

    value = const TafsirLoading();
    try {
      final response = await _datasource.getTafsir(surahNumber);
      _cache[surahNumber] = response.tafsir;
      value = TafsirLoaded(
        surahNumber: surahNumber,
        tafsirList: response.tafsir,
        activeAyat: ayatNumber,
      );
    } on EquranApiException catch (e) {
      value = TafsirError(e.message);
    } catch (e) {
      value = TafsirError('Terjadi kesalahan: $e');
    }
  }

  /// Pindah ke ayat sebelumnya dalam surah yang sedang dibuka.
  void prevAyat() {
    final state = value;
    if (state is! TafsirLoaded) return;
    if (state.activeAyat <= 1) return;
    value = state.copyWith(activeAyat: state.activeAyat - 1);
  }

  /// Pindah ke ayat berikutnya dalam surah yang sedang dibuka.
  void nextAyat(int totalAyat) {
    final state = value;
    if (state is! TafsirLoaded) return;
    if (state.activeAyat >= totalAyat) return;
    value = state.copyWith(activeAyat: state.activeAyat + 1);
  }

  /// Tutup/reset state ke idle.
  void close() {
    value = const TafsirIdle();
  }

  /// Hapus cache untuk surah tertentu (force refresh).
  void invalidateCache(int surahNumber) {
    _cache.remove(surahNumber);
  }
}
