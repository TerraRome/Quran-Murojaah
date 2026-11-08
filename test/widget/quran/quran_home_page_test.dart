import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran/Quran/application/bookmark_controller.dart';
import 'package:quran/Quran/application/quran_controller.dart';
import 'package:quran/Quran/doa/application/doa_controller.dart';
import 'package:quran/Quran/doa/data/datasources/doa_local_datasource.dart';
import 'package:quran/Quran/doa/data/datasources/doa_remote_datasource.dart';
import 'package:quran/Quran/doa/data/models/doa_model.dart';
import 'package:quran/Quran/shalat/application/location_service.dart';
import 'package:quran/Quran/shalat/application/shalat_controller.dart';
import 'package:quran/Quran/shalat/data/datasources/shalat_local_datasource.dart';
import 'package:quran/Quran/shalat/data/datasources/shalat_remote_datasource.dart';
import 'package:quran/Quran/shalat/data/models/jadwal_shalat_model.dart';
import 'package:quran/Quran/data/last_read_store.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_controller.dart';
import 'package:quran/Quran/domain/entities/surah.dart';
import 'package:quran/Quran/domain/entities/verse.dart';
import 'package:quran/Quran/domain/failures/quran_failure.dart';
import 'package:quran/Quran/domain/repositories/quran_repository.dart';
import 'package:quran/Quran/presentation/pages/quran_home_page.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  }) =>
      throw UnimplementedError();
}

class _FakeQuranRepository implements QuranRepository {
  _FakeQuranRepository(this.surahs);

  final List<Surah> surahs;

  @override
  Future<Either<QuranFailure, List<Surah>>> getSurahs() async => Right(surahs);

  @override
  Future<Either<QuranFailure, Surah>> getSurah(int number) async {
    return Right(surahs.firstWhere((s) => s.number == number));
  }
}

List<Surah> _buildSurahs() {
  Verse verse(int n) => Verse(
        number: n,
        numberInSurah: n,
        arabic: 'بِسْمِ اللهِ الرَّحْمَنِ الرَّحِيمِ',
        translation: 'Dengan menyebut nama Allah Yang Maha Pemurah.',
      );

  return [
    Surah(
      number: 1,
      name: 'الفاتحة',
      transliteration: 'Al-Fatihah',
      translation: 'Pembukaan',
      revelationType: RevelationType.meccan,
      totalVerses: 7,
      verses: [for (var i = 1; i <= 7; i++) verse(i)],
    ),
    Surah(
      number: 2,
      name: 'البقرة',
      transliteration: 'Al-Baqarah',
      translation: 'Sapi Betina',
      revelationType: RevelationType.medinan,
      totalVerses: 286,
      verses: [for (var i = 1; i <= 3; i++) verse(i)],
    ),
  ];
}

String _assetOf(SvgPicture w) =>
    (w.bytesLoader as SvgAssetLoader).assetName;

Finder _bottomNavIcon(String asset) {
  return find.byWidgetPredicate(
    (w) => w is SvgPicture && _assetOf(w) == asset,
  );
}

ColorFilter? _colorFilterOf(WidgetTester tester, String asset) {
  final icons = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
  return icons.firstWhere((w) => _assetOf(w) == asset).colorFilter;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bottom tab menampilkan 5 ikon dalam urutan yang benar',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller =
        QuranController(_FakeQuranRepository(_buildSurahs()), const LastReadStore());

    await tester.pumpWidget(
      QuranThemeScope(
        child: MaterialApp(
          home: QuranHomePage(
            controller: controller,
            doaController: DoaController(
              remote: _FakeDoaRemote(),
              local: DoaLocalDataSource(),
            ),
            shalatController: ShalatController(
              remote: _FakeShalatRemote(),
              local: ShalatLocalDataSource(),
              locationService: LocationService(),
            ),
            murojaahProgress: MurojaahProgressController(
              store: MemoryActivityStore(),
            ),
            bookmarks: BookmarkController(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final assets = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .where((w) => w.bytesLoader is SvgAssetLoader)
        .map(_assetOf)
        .toList();

    expect(
      assets,
      containsAll([
        'assets/quran/quran.svg',
        'assets/quran/lamp.svg',
        'assets/quran/shalat.svg',
        'assets/quran/doa.svg',
        'assets/quran/bookmark.svg',
      ]),
    );

    final active = _colorFilterOf(tester, 'assets/quran/quran.svg');
    final inactive = _colorFilterOf(tester, 'assets/quran/lamp.svg');
    expect(active, isNotNull);
    expect(active, isNot(equals(inactive)));
  });

  testWidgets('tap tab Murojaah menampilkan daftar surah dan menyembunyikan konten Quran',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Bottom nav kini 56dp (ikon + label): beri layar lebih tinggi supaya
    // daftar surah di bawah header Murojaah tetap terbangun.
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller =
        QuranController(_FakeQuranRepository(_buildSurahs()), const LastReadStore());

    await tester.pumpWidget(
      QuranThemeScope(
        child: MaterialApp(
          home: QuranHomePage(
            controller: controller,
            doaController: DoaController(
              remote: _FakeDoaRemote(),
              local: DoaLocalDataSource(),
            ),
            shalatController: ShalatController(
              remote: _FakeShalatRemote(),
              local: ShalatLocalDataSource(),
              locationService: LocationService(),
            ),
            murojaahProgress: MurojaahProgressController(
              store: MemoryActivityStore(),
            ),
            bookmarks: BookmarkController(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ayo baca Al-Quran hari ini'), findsOneWidget);
    expect(find.text('Al-Fatihah'), findsWidgets);

    await tester.tap(_bottomNavIcon('assets/quran/lamp.svg'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih surat untuk membuka mushaf.'), findsOneWidget);
    expect(find.text('Al-Fatihah'), findsWidgets);
    expect(find.text('Ayo baca Al-Quran hari ini'), findsNothing);

    await tester.tap(_bottomNavIcon('assets/quran/quran.svg'));
    await tester.pumpAndSettle();
    expect(find.text('Ayo baca Al-Quran hari ini'), findsOneWidget);
  });
  Widget homeApp({List<String>? visited, bool withSurahs = true}) {
    final controller = QuranController(
      _FakeQuranRepository(withSurahs ? _buildSurahs() : const []),
      const LastReadStore(),
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => QuranHomePage(
            controller: controller,
            doaController: DoaController(
              remote: _FakeDoaRemote(),
              local: DoaLocalDataSource(),
            ),
            shalatController: ShalatController(
              remote: _FakeShalatRemote(),
              local: ShalatLocalDataSource(),
              locationService: LocationService(),
            ),
            murojaahProgress: MurojaahProgressController(
              store: MemoryActivityStore(),
            ),
            bookmarks: BookmarkController(),
          ),
        ),
        GoRoute(
          path: '/home/quran/surah/:number',
          builder: (_, state) {
            visited?.add(state.uri.toString());
            return const Scaffold(body: Text('detail'));
          },
        ),
      ],
    );
    return QuranThemeScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets('bottom nav: label tampil di semua tab, >=12sp, tanpa overflow di 360dp',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Tanpa daftar surah: SurahCard sendiri sudah overflow di 360dp dengan
    // data uji (di luar lingkup nav).
    await tester.pumpWidget(homeApp(withSurahs: false));
    await tester.pumpAndSettle();

    final nav = find.byKey(const ValueKey('quran-bottom-nav'));
    for (final label in ['Quran', 'Murojaah', 'Shalat', 'Doa', 'Bookmark']) {
      final f = find.descendant(of: nav, matching: find.text(label));
      expect(f, findsOneWidget, reason: label);
      expect(tester.widget<Text>(f).style!.fontSize, greaterThanOrEqualTo(12));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom nav: label utuh tanpa overflow di 360dp skala 2.0 (BC-08-2)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(homeApp(withSurahs: false));
    await tester.pumpAndSettle();

    final nav = find.byKey(const ValueKey('quran-bottom-nav'));
    for (final label in ['Quran', 'Murojaah', 'Shalat', 'Doa', 'Bookmark']) {
      final f = find.descendant(of: nav, matching: find.text(label));
      expect(f, findsOneWidget, reason: label);
      final box = find.ancestor(of: f, matching: find.byType(FittedBox));
      expect(tester.getSize(box.first).width, lessThanOrEqualTo(360 / 5),
          reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab Bookmark: tanpa "Segera hadir", tampil petunjuk', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(homeApp());
    await tester.pumpAndSettle();

    await tester.tap(_bottomNavIcon('assets/quran/bookmark.svg'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Segera hadir'), findsNothing);
    expect(find.textContaining('Belum ada ayat yang disimpan'), findsOneWidget);
  });

  testWidgets('kartu Surat Yasin membuka surah 36 (>=48dp, berlabel)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final visited = <String>[];
    await tester.pumpWidget(homeApp(visited: visited));
    await tester.pumpAndSettle();

    final card = find.bySemanticsLabel('Buka Surat Yasin');
    expect(card, findsOneWidget);
    expect(tester.getSize(card).height, greaterThanOrEqualTo(48));

    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(visited, ['/home/quran/surah/36']);
  });
}
