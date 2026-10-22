import 'package:flutter/material.dart';
import 'package:quran/Quran/application/quran_controller.dart';
import 'package:quran/Quran/data/last_read_store.dart';
import 'package:quran/Quran/domain/entities/surah.dart';
import 'package:quran/Quran/domain/entities/verse.dart';
import 'package:quran/Quran/domain/failures/quran_failure.dart';
import 'package:quran/Quran/domain/repositories/quran_repository.dart';
import 'package:quran/Quran/presentation/pages/surah_detail_page.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'navigasi Previous/Next tampil di akhir daftar dan scroll balik ke atas tetap berfungsi',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    final surahs = _buildSurahs();
    final controller =
        QuranController(_FakeQuranRepository(surahs), const LastReadStore());

    await tester.pumpWidget(
      QuranThemeScope(
        child: MaterialApp(
          home: SurahDetailPage(surahNumber: 1, controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollableFinder = find.byType(Scrollable).last;
    expect(scrollableFinder, findsOneWidget);
    final position = tester.state<ScrollableState>(scrollableFinder).position;

    await tester.fling(scrollableFinder, const Offset(0, -4000), 8000);
    await tester.pumpAndSettle();
    final bottomPixels = position.pixels;
    expect(bottomPixels, greaterThan(0));
    expect(position.atEdge, isTrue);

    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.fling(scrollableFinder, const Offset(0, 4000), 8000);
    await tester.pumpAndSettle();
    expect(position.pixels, lessThan(bottomPixels));
  });
}
