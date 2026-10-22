import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:quran/Quran/application/quran_controller.dart';
import 'package:quran/Quran/data/last_read_store.dart';
import 'package:quran/Quran/data/quran_tokens.dart';
import 'package:quran/Quran/domain/entities/surah.dart';
import 'package:quran/Quran/domain/entities/verse.dart';
import 'package:quran/Quran/domain/failures/quran_failure.dart';
import 'package:quran/Quran/domain/repositories/quran_repository.dart';
import 'package:quran/Quran/murojaah/presentation/pages/murojaah_page.dart';
import 'package:quran/Quran/murojaah/progress/activity_entry.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_controller.dart';
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

Surah _surah(int number, String name) => Surah(
  number: number,
  name: 'الفاتحة',
  transliteration: name,
  translation: 'Pembukaan',
  revelationType: RevelationType.meccan,
  totalVerses: 7,
  verses: [
    const Verse(
      number: 1,
      numberInSurah: 1,
      arabic: 'بِسْمِ اللهِ',
      translation: 'Dengan menyebut nama Allah.',
    ),
  ],
);

Future<MurojaahProgressController> _progress(
  List<ActivityEntry> seed,
) async {
  final controller = MurojaahProgressController(
    store: MemoryActivityStore(seed),
  );
  await controller.load();
  return controller;
}

Widget _app({
  required QuranController controller,
  required MurojaahProgressController progress,
  bool dark = false,
}) {
  final router = GoRouter(
    initialLocation: '/home/quran/murojaah',
    routes: [
      GoRoute(
        path: '/home/quran/murojaah',
        builder: (context, _) => Scaffold(
          body: CustomScrollView(
            slivers: [
              MurojaahPage(controller: controller, progress: progress),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/home/quran/murojaah/surah/:number',
        builder: (context, state) =>
            Scaffold(body: Text('surah ${state.pathParameters['number']}')),
      ),
    ],
  );

  return QuranThemeScope(
    child: MaterialApp.router(
      theme: QuranTokens.themeData(dark),
      routerConfig: router,
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('log kosong: kartu mengajak mulai ke surah pertama', (
    tester,
  ) async {
    final controller = QuranController(
      _FakeQuranRepository([_surah(1, 'Al-Fatihah'), _surah(2, 'Al-Baqarah')]),
      const LastReadStore(),
    );
    await tester.pumpWidget(
      _app(controller: controller, progress: await _progress([])),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Mulai murojaah Al-Fatihah'), findsOneWidget);
    expect(find.textContaining('Lanjutkan murojaah'), findsNothing);
  });

  testWidgets('log terisi: kartu melanjutkan surah terakhir yang dicatat', (
    tester,
  ) async {
    final controller = QuranController(
      _FakeQuranRepository([_surah(1, 'Al-Fatihah'), _surah(2, 'Al-Baqarah')]),
      const LastReadStore(),
    );
    await tester.pumpWidget(
      _app(
        controller: controller,
        progress: await _progress([
          ActivityEntry(
            at: DateTime.now(),
            surahNumber: 2,
            fromVerse: 1,
            toVerse: 3,
            accuracy: 1,
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Lanjutkan murojaah Al-Baqarah'), findsOneWidget);
  });

  testWidgets('mengetuk kartu membuka surah terakhir', (tester) async {
    final controller = QuranController(
      _FakeQuranRepository([_surah(1, 'Al-Fatihah'), _surah(2, 'Al-Baqarah')]),
      const LastReadStore(),
    );
    await tester.pumpWidget(
      _app(
        controller: controller,
        progress: await _progress([
          ActivityEntry(
            at: DateTime.now(),
            surahNumber: 2,
            fromVerse: 1,
            toVerse: 3,
            accuracy: 1,
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Lanjutkan murojaah Al-Baqarah'));
    await tester.pumpAndSettle();

    expect(find.text('surah 2'), findsOneWidget);
  });
}
