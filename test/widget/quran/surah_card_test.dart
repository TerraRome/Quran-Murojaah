import 'package:flutter/material.dart';
import 'package:quran/Quran/domain/entities/surah.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:quran/Quran/presentation/widgets/surah_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const surah = Surah(
    number: 2,
    name: 'البقرة',
    transliteration: 'Al-Baqarah',
    translation: 'Sapi Betina',
    revelationType: RevelationType.medinan,
    totalVerses: 286,
    verses: [],
  );

  testWidgets('list card menampilkan meta Bahasa Indonesia (Madinah · N Ayat)',
      (tester) async {
    await tester.pumpWidget(
      const QuranThemeScope(
        child: MaterialApp(
          home: Scaffold(
            body: SurahCard(surah: surah),
          ),
        ),
      ),
    );

    expect(find.text('Madinah'), findsOneWidget);
    expect(find.text('286 Ayat'), findsOneWidget);
    expect(find.text('MADINAH'), findsNothing);
    expect(find.text('286 VERSES'), findsNothing);
  });

  testWidgets('nomor 3 digit utuh tanpa overflow di 360dp skala 2.0 (NF-1)',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const QuranThemeScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: SurahCard(
                surah: Surah(
                  number: 114,
                  name: 'الناس',
                  transliteration: 'An-Nas',
                  translation: 'Manusia',
                  revelationType: RevelationType.meccan,
                  totalVerses: 6,
                  verses: [],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('114'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
