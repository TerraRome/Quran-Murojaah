import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/data/quran_tokens.dart';
import 'package:quran/Quran/murojaah/presentation/widgets/murojaah_week_calendar.dart';
import 'package:quran/Quran/murojaah/progress/progress_service.dart';

DayActivity _day(int offsetFromToday, {int verses = 0, bool freeRest = false}) {
  final today = DateTime.now();
  final day = DateTime(today.year, today.month, today.day + offsetFromToday);
  return DayActivity(
    day: day,
    verses: verses,
    active: verses >= 1,
    freeRest: freeRest,
    isToday: offsetFromToday == 0,
  );
}

Widget _app(List<DayActivity> days, {bool dark = false}) => MaterialApp(
  theme: QuranTokens.themeData(dark),
  home: Scaffold(
    backgroundColor: QuranTokens.background(dark),
    body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: MurojaahWeekCalendar(days: days),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSmall(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets('hari aktif berikon centang, hari kosong tidak', (tester) async {
    await pumpSmall(tester, _app([_day(-2, verses: 3), _day(-1), _day(0)]));

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hari libur memakai ikon berbeda', (tester) async {
    await pumpSmall(
      tester,
      _app([_day(-2, verses: 3), _day(-1, freeRest: true), _day(0)]),
    );

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hari ini bergaris tepi tegas', (tester) async {
    await pumpSmall(tester, _app([_day(-1), _day(0)]));

    // Kolom hari ini: lingkaran kosong dengan garis tepi warna ink, bukan border.
    final circles = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => c.decoration is BoxDecoration)
        .map((c) => c.decoration as BoxDecoration)
        .where((d) => d.shape == BoxShape.circle)
        .toList();
    expect(circles, isNotEmpty);
    expect(
      circles.any(
        (d) => (d.border as Border?)?.top.color == QuranTokens.inkColor(false),
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tujuh kolom muat di lebar 360px tanpa overflow', (tester) async {
    final days = [
      for (var i = -6; i <= 0; i++) _day(i, verses: i.isEven ? 2 : 0),
    ];
    await pumpSmall(tester, _app(days));

    expect(find.byType(MurojaahWeekCalendar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('semantics per hari menyebut status dan hari ini', (
    tester,
  ) async {
    // 1 Jan 2024 = Senin; tanggal tetap supaya nama hari tidak ikut berubah.
    DayActivity explicit(
      DateTime day, {
      int verses = 0,
      bool freeRest = false,
      bool isToday = false,
    }) => DayActivity(
      day: day,
      verses: verses,
      active: verses >= 1,
      freeRest: freeRest,
      isToday: isToday,
    );

    await pumpSmall(
      tester,
      _app([
        explicit(DateTime(2024, 1, 1), verses: 3),
        explicit(DateTime(2024, 1, 2), freeRest: true),
        explicit(DateTime(2024, 1, 3), isToday: true),
      ]),
    );

    expect(find.bySemanticsLabel('Senin, sudah membaca'), findsOneWidget);
    expect(find.bySemanticsLabel('Selasa, hari libur'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Rabu, belum membaca, hari ini'),
      findsOneWidget,
    );
  });

  for (final dark in [false, true]) {
    testWidgets('render bersih mode ${dark ? 'gelap' : 'terang'}', (
      tester,
    ) async {
      await pumpSmall(
        tester,
        _app([
          _day(-2, verses: 5),
          _day(-1, freeRest: true),
          _day(0),
        ], dark: dark),
      );

      expect(find.byType(MurojaahWeekCalendar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
