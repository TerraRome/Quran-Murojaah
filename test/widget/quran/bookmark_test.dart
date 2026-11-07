import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:quran/Quran/application/bookmark_controller.dart';
import 'package:quran/Quran/application/quran_controller.dart';
import 'package:quran/Quran/data/last_read_store.dart';
import 'package:quran/Quran/domain/entities/surah.dart';
import 'package:quran/Quran/domain/entities/verse.dart';
import 'package:quran/Quran/domain/failures/quran_failure.dart';
import 'package:quran/Quran/domain/repositories/quran_repository.dart';
import 'package:quran/Quran/presentation/pages/bookmark_page.dart';
import 'package:quran/Quran/presentation/pages/surah_detail_page.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeQuranRepository implements QuranRepository {
  _FakeQuranRepository(this.surahs);

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
    translation: 'Terjemahan ayat $n.',
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
      totalVerses: 40,
      verses: [for (var i = 1; i <= 40; i++) verse(i)],
    ),
  ];
}

Future<QuranController> _loaded() async {
  final c = QuranController(
    _FakeQuranRepository(_surahs()),
    const LastReadStore(),
  );
  await c.load();
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tap simpan: ikon berubah, snackbar muncul, Batal membatalkan',
      (tester) async {
    final bookmarks = BookmarkController();
    await tester.pumpWidget(
      QuranThemeScope(
        child: MaterialApp(
          home: SurahDetailPage(
            surahNumber: 1,
            controller: await _loaded(),
            bookmarks: bookmarks,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Simpan ayat 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(bookmarks.isSaved(1, 1), isTrue);
    expect(find.text('Ayat disimpan'), findsOneWidget);
    expect(find.bySemanticsLabel('Hapus simpanan ayat 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Simpan ayat 1'), findsNothing);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(bookmarks.isSaved(1, 1), isFalse);
    expect(find.bySemanticsLabel('Simpan ayat 1'), findsOneWidget);
  });

  testWidgets('initialAyat men-scroll ke ayat tujuan', (tester) async {
    await tester.pumpWidget(
      QuranThemeScope(
        child: MaterialApp(
          home: SurahDetailPage(
            surahNumber: 2,
            controller: await _loaded(),
            initialAyat: 35,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Terjemahan ayat 35.'), findsOneWidget);
    expect(find.text('Terjemahan ayat 1.'), findsNothing);
  });

  group('BookmarkPage', () {
    Future<(BookmarkController, List<String>)> pumpPage(
      WidgetTester tester,
    ) async {
      final bookmarks = BookmarkController();
      final controller = await _loaded();
      final visited = <String>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: BookmarkPage(bookmarks: bookmarks, controller: controller),
            ),
          ),
          GoRoute(
            path: '/home/quran/surah/:number',
            builder: (_, state) {
              visited.add(state.uri.toString());
              return const Scaffold(body: Text('detail'));
            },
          ),
        ],
      );
      await tester.pumpWidget(
        QuranThemeScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      return (bookmarks, visited);
    }

    testWidgets('kosong: tampil petunjuk cara menyimpan', (tester) async {
      await pumpPage(tester);
      expect(
        find.text(
          'Belum ada ayat yang disimpan. Ketuk ikon simpan di samping ayat '
          'untuk menyimpannya.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Segera hadir'), findsNothing);
    });

    testWidgets('daftar terbaru di atas, ketuk membuka surah + ayat, hapus',
        (tester) async {
      final (bookmarks, visited) = await pumpPage(tester);
      await bookmarks.toggle(1, 3, at: DateTime(2026, 1, 1));
      await bookmarks.toggle(2, 30, at: DateTime(2026, 1, 2));
      await tester.pumpAndSettle();

      final newer = tester.getTopLeft(find.text('Al-Baqarah · Ayat 30'));
      final older = tester.getTopLeft(find.text('Al-Fatihah · Ayat 3'));
      expect(newer.dy, lessThan(older.dy));
      expect(find.text('Terjemahan ayat 30.'), findsOneWidget);

      await tester.tap(find.text('Al-Baqarah · Ayat 30'));
      await tester.pumpAndSettle();
      expect(visited, ['/home/quran/surah/2?ayat=30']);

      // Kembali ke daftar, lalu hapus satu.
      Navigator.of(tester.element(find.text('detail'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hapus simpanan ayat 3 Al-Fatihah'));
      await tester.pumpAndSettle();
      expect(bookmarks.isSaved(1, 3), isFalse);
      expect(find.text('Al-Fatihah · Ayat 3'), findsNothing);
      expect(find.text('Al-Baqarah · Ayat 30'), findsOneWidget);
    });
  });
}
