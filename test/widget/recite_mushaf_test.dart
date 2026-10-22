import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/recite/widgets/recite_mushaf.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:recite_quran/recite_quran.dart';
import 'package:shared_preferences/shared_preferences.dart';

QuranVerse _v(int ayah, String text) => QuranVerse(
      surah: 1,
      ayah: ayah,
      textUthmani: text,
      uthmaniWords: text.split(' '),
      textPhoneme: text,
      phonemeWords: text.split(' '),
      surahName: 'الفاتحة',
      surahNameEn: 'Al-Fatihah',
    );

Future<List<TextSpan>> _spans(
  WidgetTester t,
  List<QuranVerse> verses,
  Set<int> matched, {
  int? peekWord,
}) async {
  await t.pumpWidget(
    MaterialApp(
      home: QuranThemeScope(
        child: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: ReciteMushaf(
              verses: verses,
              matched: matched,
              missed: const {},
              activeVerse: 0,
              peekWord: peekWord,
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  final rich = t.widget<RichText>(
    find
        .descendant(of: find.byType(ReciteMushaf), matching: find.byType(RichText))
        .first,
  );
  return (rich.text as TextSpan).children!.cast<TextSpan>();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('only matched words are visible; the rest stay transparent',
      (t) async {
    final verses = [_v(1, 'بسم الله'), _v(2, 'الحمد لله')];

    expect(
      (await _spans(t, verses, {})).where((s) => s.style?.color == Colors.transparent).length,
      4,
    );
    // Kata ke-3 (global index 2) terbuka → 3 kata masih tertutup.
    expect(
      (await _spans(t, verses, {0, 1, 2}))
          .where((s) => s.style?.color == Colors.transparent)
          .length,
      1,
    );
    expect(
      (await _spans(t, verses, {0, 1, 2, 3}))
          .where((s) => s.style?.color == Colors.transparent)
          .length,
      0,
    );
  });

  testWidgets('peek menampilkan satu kata tanpa menandainya hafal', (t) async {
    final verses = [_v(1, 'بسم الله')];
    final spans = await _spans(t, verses, {}, peekWord: 1);
    expect(spans.where((s) => s.style?.color == Colors.transparent).length, 1);
    expect(
      spans.where((s) => s.style?.color != Colors.transparent && s.text == 'الله').length,
      1,
    );
  });

  testWidgets('ketuk kata memanggil onWordTap dengan id kata', (t) async {
    final verses = [_v(1, 'بسم الله الرحمن')];
    int? tapped;
    await t.pumpWidget(
      MaterialApp(
        home: QuranThemeScope(
          child: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: ReciteMushaf(
                verses: verses,
                matched: const {},
                missed: const {},
                activeVerse: 0,
                onWordTap: (id) => tapped = id,
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    // Teks RTL mulai dari kanan: ketuk dekat tepi kanan baris pertama.
    final rect = t.getRect(
      find
          .descendant(of: find.byType(ReciteMushaf), matching: find.byType(RichText))
          .first,
    );
    await t.tapAt(Offset(rect.right - 12, rect.top + 20));
    expect(tapped, 0);
  });
}
