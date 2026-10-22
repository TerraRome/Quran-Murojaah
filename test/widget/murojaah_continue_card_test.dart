import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/data/quran_tokens.dart';
import 'package:quran/Quran/murojaah/presentation/widgets/murojaah_continue_card.dart';

Widget _app({
  required int surahNumber,
  required String surahName,
  required bool hasHistory,
  required VoidCallback onTap,
  bool dark = false,
}) => MaterialApp(
  theme: QuranTokens.themeData(dark),
  home: Scaffold(
    backgroundColor: QuranTokens.background(dark),
    body: MurojaahContinueCard(
      surahNumber: surahNumber,
      surahName: surahName,
      hasHistory: hasHistory,
      onTap: onTap,
    ),
  ),
);

void main() {
  Future<void> pumpSmall(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets('log kosong: "Mulai murojaah" untuk surah 1', (tester) async {
    var taps = 0;
    await pumpSmall(
      tester,
      _app(
        surahNumber: 1,
        surahName: 'Al-Fatihah',
        hasHistory: false,
        onTap: () => taps++,
      ),
    );

    expect(find.text('Mulai murojaah Al-Fatihah'), findsOneWidget);
    expect(find.textContaining('Lanjutkan'), findsNothing);
    expect(find.text('Surah 1 · Al-Fatihah'), findsOneWidget);

    await tester.tap(find.text('Mulai murojaah Al-Fatihah'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('log terisi: "Lanjutkan murojaah" ke surah terakhir', (
    tester,
  ) async {
    var taps = 0;
    await pumpSmall(
      tester,
      _app(
        surahNumber: 36,
        surahName: 'Yasin',
        hasHistory: true,
        onTap: () => taps++,
      ),
    );

    expect(find.text('Lanjutkan murojaah Yasin'), findsOneWidget);
    await tester.tap(find.text('Lanjutkan murojaah Yasin'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('target sentuh tombol ≥48px', (tester) async {
    await pumpSmall(
      tester,
      _app(
        surahNumber: 1,
        surahName: 'Al-Fatihah',
        hasHistory: false,
        onTap: () {},
      ),
    );

    final size = tester.getSize(find.byType(InkWell));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
  });

  for (final dark in [false, true]) {
    testWidgets('render bersih mode ${dark ? 'gelap' : 'terang'}', (
      tester,
    ) async {
      await pumpSmall(
        tester,
        _app(
          surahNumber: 2,
          surahName: 'Al-Baqarah',
          hasHistory: true,
          onTap: () {},
          dark: dark,
        ),
      );

      expect(find.byType(MurojaahContinueCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
