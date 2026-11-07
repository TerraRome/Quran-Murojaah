import 'package:flutter/material.dart';
import 'package:quran/Quran/domain/entities/verse.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:quran/Quran/presentation/widgets/verse_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const verse = Verse(
    number: 2,
    numberInSurah: 2,
    arabic: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
    translation: 'Segala puji bagi Allah, Tuhan seluruh alam.',
  );

  const latinVerse = Verse(
    number: 2,
    numberInSurah: 2,
    arabic: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
    translation: 'Segala puji bagi Allah, Tuhan seluruh alam.',
    transliteration: 'Alḥamdu lillāhi rabbil-ʿālamīn(a).',
  );

  Widget wrap({bool showDivider = true, Verse v = verse}) => QuranThemeScope(
        child: MaterialApp(
          home: Scaffold(
            body: VerseView(verse: v, surahNumber: 1, showDivider: showDivider),
          ),
        ),
      );

  Future<void> pumpWithPrefs(
    WidgetTester tester,
    Map<String, Object> prefs,
  ) async {
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(wrap(v: latinVerse));
    await tester.pumpAndSettle();
  }

  testWidgets('latin tampil miring di antara Arab dan terjemahan',
      (tester) async {
    await pumpWithPrefs(tester, {});
    final f = find.text('Alḥamdu lillāhi rabbil-ʿālamīn(a).');
    expect(f, findsOneWidget);
    expect(tester.widget<Text>(f).style!.fontStyle, FontStyle.italic);
    expect(tester.getTopLeft(f).dy,
        lessThan(tester.getTopLeft(find.text(latinVerse.translation)).dy));
  });

  testWidgets('latin disembunyikan oleh toggle', (tester) async {
    await pumpWithPrefs(tester, {'quran_show_latin': false});
    expect(find.text(latinVerse.transliteration), findsNothing);
    expect(find.text(latinVerse.translation), findsOneWidget);
  });

  testWidgets('latin kosong: baris tidak tampil', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is Text && w.style?.fontStyle == FontStyle.italic),
        findsNothing);
  });

  testWidgets('terjemahan disembunyikan oleh toggle', (tester) async {
    await pumpWithPrefs(tester, {'quran_show_translation': false});
    expect(find.text(latinVerse.translation), findsNothing);
    expect(find.text(latinVerse.transliteration), findsOneWidget);
  });

  testWidgets('BC-04: ikon aksi >=48dp dan berlabel', (tester) async {
    final handle = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    for (final l in [
      'Putar ayat 2',
      'Simpan ayat 2',
      'Bagikan ayat 2',
      'Tafsir ayat 2',
    ]) {
      expect(find.bySemanticsLabel(l), findsOneWidget);
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

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
