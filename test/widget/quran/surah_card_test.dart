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
}
