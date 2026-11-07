import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:quran/Quran/application/bookmark_controller.dart';
import 'package:quran/Quran/application/quran_controller.dart';
import 'package:quran/Quran/data/last_read_store.dart';
import 'package:quran/Quran/doa/application/doa_controller.dart';
import 'package:quran/Quran/doa/data/datasources/doa_local_datasource.dart';
import 'package:quran/Quran/doa/data/datasources/doa_remote_datasource.dart';
import 'package:quran/Quran/doa/data/models/doa_model.dart';
import 'package:quran/Quran/domain/entities/surah.dart';
import 'package:quran/Quran/domain/entities/verse.dart';
import 'package:quran/Quran/domain/failures/quran_failure.dart';
import 'package:quran/Quran/domain/repositories/quran_repository.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_controller.dart';
import 'package:quran/Quran/presentation/pages/quran_home_page.dart';
import 'package:quran/Quran/presentation/pages/surah_detail_page.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:quran/Quran/shalat/application/location_service.dart';
import 'package:quran/Quran/shalat/application/shalat_controller.dart';
import 'package:quran/Quran/shalat/data/datasources/shalat_local_datasource.dart';
import 'package:quran/Quran/shalat/data/datasources/shalat_remote_datasource.dart';
import 'package:quran/Quran/shalat/data/models/jadwal_shalat_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fase 1 PRD: NF-01..NF-04 di halaman Quran dan detail surah.

class _FakeDoaRemote implements DoaRemoteDataSource {
  @override
  Future<List<DoaModel>> getDoas() async => const [];

  @override
  Future<DoaModel> getDoaDetail(int id) => throw UnimplementedError();
}

class _FakeShalatRemote implements ShalatRemoteDataSource {
  @override
  Future<List<String>> getProvinsi() async => const [];

  @override
  Future<List<String>> getKabkota(String provinsi) async => const [];

  @override
  Future<JadwalShalatModel> getJadwalShalat({
    required String provinsi,
    required String kabkota,
    int? bulan,
    int? tahun,
  }) => throw UnimplementedError();
}

class _FakeRepo implements QuranRepository {
  _FakeRepo(this.surahs);
  final List<Surah> surahs;

  @override
  Future<Either<QuranFailure, List<Surah>>> getSurahs() async => Right(surahs);

  @override
  Future<Either<QuranFailure, Surah>> getSurah(int number) async =>
      Right(surahs.firstWhere((s) => s.number == number));
}

List<Surah> _surahs() {
  Verse verse(int n) => Verse(
    number: n,
    numberInSurah: n,
    arabic: 'بِسْمِ اللهِ الرَّحْمَنِ الرَّحِيمِ',
    translation:
        'Dengan menyebut nama Allah Yang Maha Pemurah lagi Maha Penyayang.',
    transliteration: "Bismillāhir-raḥmānir-raḥīm(i).",
  );
  Surah s(
    int n,
    String name,
    String latin,
    String tr,
    RevelationType t,
    int v,
  ) => Surah(
    number: n,
    name: name,
    transliteration: latin,
    translation: tr,
    revelationType: t,
    totalVerses: v,
    verses: [for (var i = 1; i <= 4; i++) verse(i)],
  );
  return [
    s(1, 'الفاتحة', 'Al-Fatihah', 'Pembukaan', RevelationType.meccan, 7),
    s(2, 'البقرة', 'Al-Baqarah', 'Sapi Betina', RevelationType.medinan, 286),
    s(
      3,
      'آل عمران',
      "Ali 'Imran",
      'Keluarga Imran',
      RevelationType.medinan,
      200,
    ),
    s(4, 'النساء', "An-Nisa'", 'Wanita', RevelationType.medinan, 176),
    s(36, 'يس', 'Ya-Sin', 'Yasin', RevelationType.meccan, 83),
    s(114, 'الناس', 'An-Nas', 'Manusia', RevelationType.meccan, 6),
  ];
}

Future<void> _pump(
  WidgetTester tester, {
  required bool dark,
  required double scale,
  required Widget Function(QuranController) page,
}) async {
  SharedPreferences.setMockInitialValues({
    'quran_theme_dark': dark,
    'quran_last_read_surah': 2,
    'quran_last_read_verse': 255,
  });
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = QuranController(
    _FakeRepo(_surahs()),
    const LastReadStore(),
  );
  await tester.pumpWidget(
    QuranThemeScope(
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: page(controller),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _home(QuranController c) => QuranHomePage(
  controller: c,
  doaController: DoaController(
    remote: _FakeDoaRemote(),
    local: DoaLocalDataSource(),
  ),
  shalatController: ShalatController(
    remote: _FakeShalatRemote(),
    local: ShalatLocalDataSource(),
    locationService: LocationService(),
  ),
  murojaahProgress: MurojaahProgressController(store: MemoryActivityStore()),
  bookmarks: BookmarkController(),
);

Widget _detail(QuranController c) => SurahDetailPage(
  surahNumber: 2,
  controller: c,
  bookmarks: BookmarkController(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Halaman detail mengecek file murottal lokal lewat path_provider.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => Directory.systemTemp.path,
      );

  final pages = <String, Widget Function(QuranController)>{
    'QuranHomePage': _home,
    'SurahDetailPage': _detail,
  };

  pages.forEach((name, page) {
    group(name, () {
      testWidgets('NF-01 area sentuh 48dp', (tester) async {
        final h = tester.ensureSemantics();
        await _pump(tester, dark: false, scale: 1, page: page);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        h.dispose();
      });

      testWidgets('NF-02 tombol punya label', (tester) async {
        final h = tester.ensureSemantics();
        await _pump(tester, dark: false, scale: 1, page: page);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        h.dispose();
      });

      for (final dark in [false, true]) {
        testWidgets('NF-03 kontras teks ${dark ? 'gelap' : 'terang'}', (
          tester,
        ) async {
          final h = tester.ensureSemantics();
          await _pump(tester, dark: dark, scale: 1, page: page);
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          h.dispose();
        });
      }

      for (final scale in [1.0, 2.0]) {
        testWidgets('NF-04 tanpa overflow di 360dp skala $scale', (
          tester,
        ) async {
          await _pump(tester, dark: false, scale: scale, page: page);
          expect(tester.takeException(), isNull);
        });
      }
    });
  });
}
