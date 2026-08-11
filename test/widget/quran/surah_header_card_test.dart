import 'package:flutter/material.dart';
import 'package:flutter_portfolio/Quran/domain/entities/surah.dart';
import 'package:flutter_portfolio/Quran/domain/entities/verse.dart';
import 'package:flutter_portfolio/Quran/presentation/widgets/surah_header_card.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const surah = Surah(
    number: 1,
    name: 'الفاتحة',
    transliteration: 'Al-Fatihah',
    translation: 'Pembukaan',
    revelationType: RevelationType.meccan,
    totalVerses: 7,
    verses: [Verse(number: 1, numberInSurah: 1, arabic: 'بِسْمِ', translation: 'Dengan nama')],
  );

  testWidgets('header card menampilkan urutan konten baru dalam Bahasa Indonesia',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SurahHeaderCard(surah: surah),
          ),
        ),
      ),
    );

    expect(find.text('Al-Fatihah'), findsOneWidget);
    expect(find.text('Pembukaan'), findsOneWidget);
    expect(find.text('Mekkah'), findsOneWidget);
    expect(find.text('7 Ayat'), findsOneWidget);
    expect(find.text('الفاتحة'), findsNothing);

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SurahHeaderCard),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );

    expect(find.byType(FractionallySizedBox), findsOneWidget);
  });
}
