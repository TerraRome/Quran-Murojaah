import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/data/quran_tokens.dart';
import 'package:quran/Quran/murojaah/presentation/widgets/murojaah_goal_picker.dart';
import 'package:quran/Quran/murojaah/presentation/widgets/murojaah_progress_header.dart';
import 'package:quran/Quran/murojaah/progress/activity_entry.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_controller.dart';
import 'package:quran/Quran/murojaah/progress/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

ActivityEntry _today(int verses) => ActivityEntry(
  at: DateTime.now(),
  surahNumber: 1,
  fromVerse: 1,
  toVerse: verses,
  accuracy: 1,
);

Future<MurojaahProgressController> _controller(List<ActivityEntry> seed) async {
  final controller = MurojaahProgressController(
    store: MemoryActivityStore(seed),
  );
  await controller.load();
  return controller;
}

/// Header saja; tombol "Atur target" di dalamnya membuka sheet.
Widget _app(MurojaahProgressController progress, {bool dark = false}) =>
    MaterialApp(
      theme: QuranTokens.themeData(dark),
      home: Scaffold(
        backgroundColor: QuranTokens.background(dark),
        body: SingleChildScrollView(
          child: MurojaahProgressHeader(progress: progress),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpSmall(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets('tiga pilihan tampil dengan label dan jumlah ayat', (
    tester,
  ) async {
    final progress = await _controller([_today(4)]);
    await pumpSmall(tester, _app(progress));
    await tester.tap(find.text('Atur target'));
    await tester.pumpAndSettle();

    for (final goal in DailyGoal.values) {
      expect(find.text(goal.label), findsOneWidget);
      expect(find.text(goal.detail), findsOneWidget);
      expect(find.text('${goal.verses} ayat'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('pilihan aktif ditandai ikon centang DAN garis tepi', (
    tester,
  ) async {
    final progress = await _controller([_today(4)]);
    await pumpSmall(tester, _app(progress));
    await tester.tap(find.text('Atur target'));
    await tester.pumpAndSettle();

    // Default controller: Sedang.
    expect(progress.goal, DailyGoal.sedang);
    // Dua centang: satu di kalender (hari ini aktif), satu di baris terpilih.
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );

    final selected = tester.widget<Container>(
      find
          .ancestor(
            of: find.text(DailyGoal.sedang.label),
            matching: find.byType(Container),
          )
          .first,
    );
    final border = (selected.decoration as BoxDecoration).border as Border;
    expect(border.top.width, 2);
    expect(border.top.color, QuranTokens.correct(false));

    final other = tester.widget<Container>(
      find
          .ancestor(
            of: find.text(DailyGoal.ringan.label),
            matching: find.byType(Container),
          )
          .first,
    );
    final otherBorder = (other.decoration as BoxDecoration).border as Border;
    expect(otherBorder.top.width, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('memilih target menutup sheet, menyimpan, dan cincin berubah', (
    tester,
  ) async {
    final progress = await _controller([_today(4)]);
    await pumpSmall(tester, _app(progress));

    // Sebelum: 4 dari 15.
    expect(find.text('4/15'), findsOneWidget);

    await tester.tap(find.text('Atur target'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DailyGoal.serius.label));
    await tester.pumpAndSettle();

    // Sheet tertutup.
    expect(find.text('Atur target harian'), findsNothing);

    // Header sendiri yang memanggil setGoal — tanpa bantuan test.
    expect(progress.goal, DailyGoal.serius);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('quran_murojaah_goal_verses'), 30);

    // Cincin ikut berubah tanpa load() ulang (isLoaded tetap true).
    expect(progress.isLoaded, isTrue);
    expect(find.text('4/30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('riwayat dan streak tidak berubah saat target berganti', (
    tester,
  ) async {
    final now = DateTime.now();
    final progress = await _controller([
      ActivityEntry(
        at: now.subtract(const Duration(days: 1)),
        surahNumber: 1,
        fromVerse: 1,
        toVerse: 4,
        accuracy: 1,
      ),
      _today(4),
    ]);
    await pumpSmall(tester, _app(progress));

    final before = progress.snapshot(now: now);
    expect(find.text('2 hari berturut-turut'), findsOneWidget);

    await progress.setGoal(DailyGoal.ringan);
    await tester.pumpAndSettle();

    final after = progress.snapshot(now: now);
    expect(after.streak, before.streak);
    expect(after.totalXp, before.totalXp);
    expect(progress.entries.length, 2);
    expect(find.text('2 hari berturut-turut'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tombol Atur target ada meski log kosong', (tester) async {
    final progress = await _controller(const []);
    await pumpSmall(tester, _app(progress));

    expect(find.text('Atur target'), findsOneWidget);
    final size = tester.getSize(find.text('Atur target'));
    expect(size.height, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('sheet render bersih mode ${dark ? 'gelap' : 'terang'}', (
      tester,
    ) async {
      final progress = await _controller([_today(4)]);
      await pumpSmall(tester, _app(progress, dark: dark));
      await tester.tap(find.text('Atur target'));
      await tester.pumpAndSettle();

      expect(find.text('Atur target harian'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
