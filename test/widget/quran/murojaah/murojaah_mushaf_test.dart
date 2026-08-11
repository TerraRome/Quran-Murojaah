import 'package:flutter/material.dart';
import 'package:flutter_portfolio/Quran/data/quran_tokens.dart';
import 'package:flutter_portfolio/Quran/domain/entities/surah.dart';
import 'package:flutter_portfolio/Quran/domain/entities/verse.dart';
import 'package:flutter_portfolio/Quran/murojaah/application/murojaah_controller.dart';
import 'package:flutter_portfolio/Quran/murojaah/presentation/widgets/murojaah_mushaf.dart';
import 'package:flutter_portfolio/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:flutter_test/flutter_test.dart';

Surah _surahIkhlas() {
  Verse v(int n) => Verse(
        number: 112000 + n,
        numberInSurah: n,
        arabic: 'قُلْ هُوَ اللهُ أَحَدٌ',
        translation: 'Katakanlah: Dialah Allah Yang Maha Esa.',
      );
  return Surah(
    number: 112,
    name: 'الاخلاص',
    transliteration: 'Al-Ikhlas',
    translation: 'Ikhlas',
    revelationType: RevelationType.meccan,
    totalVerses: 4,
    verses: [for (var i = 1; i <= 4; i++) v(i)],
  );
}

/// Jumlah span teks ayat yang dicat warna background (tersembunyi).
int _hiddenSpanCount(WidgetTester tester) {
  final rich = tester.widget<RichText>(
    find.byWidgetPredicate(
      (w) => w is RichText && w.textDirection == TextDirection.rtl,
    ),
  );
  final bg = QuranTokens.background(false);
  int count = 0;
  for (final child in (rich.text as TextSpan).children ?? const []) {
    final span = child as TextSpan;
    if (span.text?.contains('۝') == false && span.style?.color == bg) {
      count++;
    }
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(MurojaahController controller) {
    return QuranThemeScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: 350,
                child: MurojaahMushaf(
                  surah: _surahIkhlas(),
                  controller: controller,
                  dark: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('mushaf merender satu aliran teks RTL', (tester) async {
    final controller = MurojaahController();
    await tester.pumpWidget(host(controller));
    await tester.pumpAndSettle();

    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    final mushaf = richTexts.firstWhere(
      (r) => r.textDirection == TextDirection.rtl,
      orElse: () => throw StateError('Tidak ada RichText RTL'),
    );
    expect(mushaf.textDirection, TextDirection.rtl);
    // Semua ayat dirender dalam satu span teks.
    expect(mushaf.text.toPlainText(), contains('قُلْ هُوَ اللهُ أَحَدٌ'));
    expect(mushaf.text.toPlainText(), contains('۝'));
  });

  testWidgets('semua ayat tersembunyi saat awal, reveal membuka satu per satu',
      (tester) async {
    final controller = MurojaahController();
    await tester.pumpWidget(host(controller));
    await tester.pumpAndSettle();

    expect(_hiddenSpanCount(tester), 4);

    controller.revealNext(surahNumber: 112, totalVerses: 4);
    await tester.pumpAndSettle();
    expect(_hiddenSpanCount(tester), 3);

    controller.revealNext(surahNumber: 112, totalVerses: 4);
    await tester.pumpAndSettle();
    expect(_hiddenSpanCount(tester), 2);
  });

  testWidgets('reset menyembunyikan seluruh ayat kembali', (tester) async {
    final controller = MurojaahController();
    controller.revealNext(surahNumber: 112, totalVerses: 4);
    controller.revealNext(surahNumber: 112, totalVerses: 4);
    await tester.pumpWidget(host(controller));
    await tester.pumpAndSettle();
    expect(_hiddenSpanCount(tester), 2);

    controller.resetReveal(surahNumber: 112, totalVerses: 4);
    await tester.pumpAndSettle();
    expect(_hiddenSpanCount(tester), 4);
  });
}