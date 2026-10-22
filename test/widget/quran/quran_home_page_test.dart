import 'package:flutter/material.dart';
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
}
