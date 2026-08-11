import 'package:flutter/material.dart';
import 'package:flutter_portfolio/Quran/domain/entities/verse.dart';
import 'package:flutter_portfolio/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:flutter_portfolio/Quran/presentation/widgets/verse_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const verse = Verse(
    number: 2,
    numberInSurah: 2,
    arabic: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
    translation: 'Segala puji bagi Allah, Tuhan seluruh alam.',
  );

  Widget wrap({bool showDivider = true}) => QuranThemeScope(
        child: MaterialApp(
          home: Scaffold(
            body: VerseView(verse: verse, surahNumber: 1, showDivider: showDivider),
          ),
        ),
      );

  testWidgets('menampilkan Arab, terjemahan, dan nomor ayat', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ'), findsOneWidget);
    expect(find.text('Segala puji bagi Allah, Tuhan seluruh alam.'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('header menampilkan 3 ikon aksi (share, play, bookmark)',
      (tester) async {
    await tester.pumpWidget(wrap());

    final icons = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .where((w) => w.bytesLoader is SvgAssetLoader)
        .map((w) => (w.bytesLoader as SvgAssetLoader).assetName)
        .toList();
    expect(
      icons,
      containsAll([
        'assets/quran/share.svg',
        'assets/quran/play.svg',
        'assets/quran/bookmark.svg',
      ]),
    );
  });

  testWidgets('divider tampil secara default dan bisa disembunyikan',
      (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.byType(Divider), findsOneWidget);

    await tester.pumpWidget(wrap(showDivider: false));
    expect(find.byType(Divider), findsNothing);
  });
}
