import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/last_read_store.dart';
import '../domain/entities/surah.dart';
import '../domain/failures/quran_failure.dart';
import '../domain/repositories/quran_repository.dart';
import 'last_read.dart';
import 'transliteration_prefetch_service.dart';

/// Status pemuatan data Quran.
enum QuranLoadStatus { initial, loading, loaded, error }

/// State sederhana module Quran (ValueNotifier, tanpa Bloc).
class QuranController extends ValueNotifier<QuranState> {
  QuranController(
    this._repository,
    this._lastReadStore, {
    TransliterationPrefetchService? transliteration,
  })  : _transliteration = transliteration,
        super(const QuranState.initial());

  final QuranRepository _repository;
  final LastReadStore _lastReadStore;

  /// Sumber latin (BC-01). Null = ayat tampil tanpa latin.
  final TransliterationPrefetchService? _transliteration;

  List<Surah> _surahs = const [];

  LastRead? _lastRead;

  List<Surah> get surahs => _surahs;

  LastRead? get lastRead => _lastRead;

  Future<void> load() async {
    value = const QuranState(status: QuranLoadStatus.loading);
    final result = await _repository.getSurahs();
    result.fold(
      (failure) {
        value = QuranState.error(failure);
      },
      (surahs) {
        _surahs = surahs;
        value = QuranState.loaded(surahs);
      },
    );
  }

  /// Suntik latin (cache, fallback online) ke ayat satu surah — `quran.json`
  /// tidak memuat latin. Mengembalikan surah terbaru; latin tidak tersedia
  /// (offline/belum pernah di-fetch) = surah apa adanya, tanpa error.
  /// Normalized text sengaja tidak disuntik: tidak dipakai matching murojaah.
  Future<Surah?> loadLatin(int surahNumber) async {
    final latin = await _transliteration?.loadForSurah(surahNumber);
    final i = _surahs.indexWhere((s) => s.number == surahNumber);
    if (i < 0) return null;
    if (latin == null || latin.isEmpty) return _surahs[i];
    final surah = _surahs[i].withVerses([
      for (final v in _surahs[i].verses)
        latin[v.numberInSurah] == null
            ? v
            : v.withTransliteration(
                transliteration: latin[v.numberInSurah]!.transliteration,
                normalizedText: v.normalizedText,
              ),
    ]);
    _surahs = [..._surahs]..[i] = surah;
    value = QuranState.loaded(_surahs);
    return surah;
  }

  /// Muat posisi baca terakhir dari penyimpanan lokal.
  Future<void> loadLastRead() async {
    _lastRead = await _lastReadStore.load();
    notifyListeners();
  }

  /// Simpan posisi baca terakhir.
  Future<void> setLastRead(int surahNumber, int verseNumber) async {
    final lastRead = LastRead(surahNumber: surahNumber, verseNumber: verseNumber);
    _lastRead = lastRead;
    notifyListeners();
    await _lastReadStore.save(lastRead);
  }
}

/// Immutable state sederhana (tanpa freezed, mengikuti keputusan project).
class QuranState {
  const QuranState({
    required this.status,
    this.surahs = const [],
    this.failure,
  });

  const QuranState.initial() : this(status: QuranLoadStatus.initial);

  const QuranState.loaded(List<Surah> surahs)
      : this(status: QuranLoadStatus.loaded, surahs: surahs);

  const QuranState.error(QuranFailure failure)
      : this(status: QuranLoadStatus.error, failure: failure);

  final QuranLoadStatus status;
  final List<Surah> surahs;
  final QuranFailure? failure;

  bool get isLoading => status == QuranLoadStatus.loading;
  bool get isError => status == QuranLoadStatus.error;
  bool get isLoaded => status == QuranLoadStatus.loaded;
}
