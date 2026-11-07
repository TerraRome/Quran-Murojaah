import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:quran/Quran/application/quran_controller.dart';
import 'package:quran/Quran/application/transliteration_prefetch_service.dart';
import 'package:quran/Quran/data/datasources/equran_remote_datasource.dart';
import 'package:quran/Quran/data/datasources/transliteration_local_datasource.dart';
import 'package:quran/Quran/data/last_read_store.dart';
import 'package:quran/Quran/domain/entities/surah.dart';
import 'package:quran/Quran/domain/entities/verse.dart';
import 'package:quran/Quran/domain/failures/quran_failure.dart';
import 'package:quran/Quran/domain/repositories/quran_repository.dart';
import 'package:quran/Quran/murojaah/tirukan/dengar_tirukan_flow.dart';
import 'package:quran/Quran/murojaah/tirukan/dengar_tirukan_page.dart';
import 'package:quran/Quran/presentation/pages/surah_detail_page.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BC-01: latin dari cache/online harus sampai ke ayat yang dirender.

class _Repo implements QuranRepository {
  @override
  Future<Either<QuranFailure, List<Surah>>> getSurahs() async => Right([_surah]);
  @override
  Future<Either<QuranFailure, Surah>> getSurah(int n) async => Right(_surah);
}

final _surah = Surah(
  number: 1,
  name: 'الفاتحة',
  transliteration: 'Al-Fatihah',
  translation: 'Pembukaan',
  revelationType: RevelationType.meccan,
  totalVerses: 2,
  verses: const [
    Verse(
      number: 1,
      numberInSurah: 1,
      arabic: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
      translation: 'Dengan menyebut nama Allah.',
    ),
    Verse(
      number: 2,
      numberInSurah: 2,
      arabic: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
      translation: 'Segala puji bagi Allah.',
    ),
  ],
);

const _latin = {1: 'Bismillāhir-raḥmānir-raḥīm', 2: 'Al-ḥamdu lillāhi rabbil-ʿālamīn'};

class _Remote implements EquranRemoteDataSource {
  _Remote({this.data, this.fail = false});
  final Map<int, String>? data;
  final bool fail;
  @override
  Future<Map<int, String>> getTransliterations(int n) async {
    if (fail) throw const EquranApiException('offline');
    return data ?? {};
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

QuranController _controller(_Remote remote) => QuranController(
      _Repo(),
      const LastReadStore(),
      transliteration: TransliterationPrefetchService(
        remote: remote,
        local: TransliterationLocalDataSource(),
      ),
    );

Widget _app(Widget home) => QuranThemeScope(child: MaterialApp(home: home));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('detail surah: latin dari cache tampil di bawah ayat', (t) async {
    // Format key/value persis TransliterationLocalDataSource.
    SharedPreferences.setMockInitialValues({
      'transliteration_surah_1': jsonEncode(
        _latin.map((k, v) => MapEntry('$k', v)),
      ),
    });
    t.view.physicalSize = const Size(800, 3000); // semua ayat muat di layar
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(SurahDetailPage(
      surahNumber: 1,
      controller: _controller(_Remote(fail: true)),
    )));
    await t.pumpAndSettle();

    expect(find.text(_latin[1]!), findsOneWidget);
    expect(find.text(_latin[2]!), findsOneWidget);
  });

  testWidgets('detail surah: cache kosong -> latin tampil setelah fallback online',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(_app(SurahDetailPage(
      surahNumber: 1,
      controller: _controller(_Remote(data: _latin)),
    )));
    await t.pumpAndSettle();

    expect(find.text(_latin[1]!), findsOneWidget);
  });

  testWidgets('detail surah: offline & belum di-cache -> tanpa latin, tanpa error',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(_app(SurahDetailPage(
      surahNumber: 1,
      controller: _controller(_Remote(fail: true)),
    )));
    await t.pumpAndSettle();

    expect(find.text(_latin[1]!), findsNothing);
    expect(find.text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('dengar-tirukan: latin ayat aktif tampil', (t) async {
    SharedPreferences.setMockInitialValues({
      'transliteration_surah_1': jsonEncode(
        _latin.map((k, v) => MapEntry('$k', v)),
      ),
    });
    await t.pumpWidget(_app(DengarTirukanPage(
      surahNumber: 1,
      controller: _controller(_Remote(fail: true)),
      flowBuilder: (s) => DengarTirukanFlow(
        totalAyat: s.totalVerses,
        recognizer: _Rec(),
        gap: () => Duration.zero,
        stopAudio: () async {},
        playAyat: (_) async => true,
      ),
    )));
    await t.pumpAndSettle();

    expect(find.text(_latin[1]!), findsOneWidget);
  });
}

class _Rec implements AyatRecognizer {
  @override
  Future<bool?> listen(int ayat) => Completer<bool?>().future;
  @override
  Future<void> cancel() async {}
}
