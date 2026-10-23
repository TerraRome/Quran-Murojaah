import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:quran/Quran/application/quran_controller.dart';
import 'package:quran/Quran/data/last_read_store.dart';
import 'package:quran/Quran/domain/entities/surah.dart';
import 'package:quran/Quran/domain/entities/verse.dart';
import 'package:quran/Quran/domain/failures/quran_failure.dart';
import 'package:quran/Quran/domain/repositories/quran_repository.dart';
import 'package:quran/Quran/murojaah/presentation/pages/hafalan_map_page.dart';
import 'package:quran/Quran/murojaah/progress/activity_entry.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_controller.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepository implements QuranRepository {
  _FakeRepository(this.surahs);

  final List<Surah> surahs;

  @override
  Future<Either<QuranFailure, List<Surah>>> getSurahs() async => Right(surahs);

  @override
  Future<Either<QuranFailure, Surah>> getSurah(int number) async =>
      Right(surahs.firstWhere((s) => s.number == number));
}

Verse _verse(int n) => Verse(
  number: n,
  numberInSurah: n,
  arabic: 'بِسْمِ اللهِ',
  translation: 'Terjemahan ayat $n.',
);

/// Hanya surah 1 (2 ayat), 2 (2 ayat), 3 (2 ayat) yang dikenal.
List<Surah> _surahs() => [
  for (final (number, name) in [
    (1, 'Al-Fatihah'),
    (2, 'Al-Baqarah'),
    (3, 'Ali Imran'),
  ])
    Surah(
      number: number,
      name: 'الفاتحة',
      transliteration: name,
      translation: 'Pembukaan',
      revelationType: RevelationType.meccan,
      totalVerses: 2,
      verses: [for (var i = 1; i <= 2; i++) _verse(i)],
    ),
];

Future<MurojaahProgressController> _progressWithLog() async {
  final progress = MurojaahProgressController(store: MemoryActivityStore());
  await progress.load();
  progress.verseCount = (number) => number <= 3 ? 2 : 0;
  final at = DateTime(2026, 10, 22, 9);
  // Surah 1 tamat + akurasi baik → Lancar.
  await progress.recordVerses(
    type: ActivityType.murojaah,
    surahNumber: 1,
    verses: const [1, 2],
    at: at,
  );
  // Surah 2 baru satu ayat → Sedang.
  await progress.recordVerses(
    type: ActivityType.murojaah,
    surahNumber: 2,
    verses: const [1],
    at: at,
  );
  return progress;
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required QuranController controller,
  required MurojaahProgressController progress,
  double textScale = 2.0,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    QuranThemeScope(
      child: MaterialApp(
        builder: (context, inner) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: inner!,
        ),
        home: HafalanMapPage(controller: controller, progress: progress),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('114 surah tampil dengan tiga status ikon + teks', (
    tester,
  ) async {
    final progress = await _progressWithLog();
    final controller = QuranController(
      _FakeRepository(_surahs()),
      const LastReadStore(),
    );
    await controller.load();

    await _pumpPage(tester, controller: controller, progress: progress);

    expect(tester.takeException(), isNull);
    expect(find.text('Peta Hafalan'), findsOneWidget);

    // Legenda: tiga status, masing-masing dengan teks pendamping.
    expect(find.text('Lancar 1'), findsOneWidget);
    expect(find.text('Sedang 1'), findsOneWidget);
    expect(find.text('Belum mulai 112'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
    expect(find.byIcon(Icons.timelapse_rounded), findsWidgets);
    expect(find.byIcon(Icons.radio_button_unchecked), findsWidgets);

    // Baris surah 1 tampil dengan status teks, bukan warna saja.
    await tester.scrollUntilVisible(find.text('Al-Fatihah'), 100);
    expect(find.text('Al-Fatihah'), findsOneWidget);
    expect(find.text('2 dari 2 ayat'), findsOneWidget);
    expect(find.text('Lancar'), findsWidgets);
  });

  testWidgets('teks 1x: baris tetap utuh tanpa overflow', (tester) async {
    final progress = await _progressWithLog();
    final controller = QuranController(
      _FakeRepository(_surahs()),
      const LastReadStore(),
    );
    await controller.load();

    await _pumpPage(
      tester,
      controller: controller,
      progress: progress,
      textScale: 1.0,
    );

    expect(tester.takeException(), isNull);
    final row = tester.getRect(find.text('Al-Fatihah'));
    expect(row.height, greaterThan(0));
  });
}
