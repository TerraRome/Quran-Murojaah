import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/recite/asr_snapshot.dart';
import 'package:quran/Quran/murojaah/recite/heard_word.dart';
import 'package:quran/Quran/murojaah/recite/widgets/recite_correction_sheet.dart';
import 'package:quran/Quran/murojaah/recite/widgets/recite_mushaf.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:recite_quran/recite_quran.dart';
import 'package:shared_preferences/shared_preferences.dart';

QuranVerse _verse(String text) => QuranVerse(
      surah: 1,
      ayah: 1,
      textUthmani: text,
      uthmaniWords: text.split(' '),
      textPhoneme: text,
      phonemeWords: text.split(' '),
      surahName: 'الفاتحة',
      surahNameEn: 'Al-Fatihah',
    );

/// Halaman mini: mushaf + sheet koreksi, persis alur di `ReciteMurojaahPage`.
Widget _page({required String expected, required String? heard}) {
  return MaterialApp(
    home: QuranThemeScope(
      child: Scaffold(
        body: SizedBox(
          width: 400,
          height: 600,
          child: Builder(
            builder: (context) => ReciteMushaf(
              verses: [_verse('بسم الله الرحمن')],
              matched: const {},
              missed: const {1},
              activeVerse: 0,
              onWordTap: (id) => showReciteCorrectionSheet(
                context,
                expected: expected,
                heard: heard,
                dark: false,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tap kata merah hasil substitusi menampilkan teks yang terdengar',
      (t) async {
    const expected = 'الرحيم';
    // "بسم الله الرحمن الرحيم" dibaca "… الرحمن كَتَبَ": slot kata ke-3 terisi
    // fonem kata lain.
    const words = ['بسم', 'الله', 'الرحمن', 'الرحيم'];
    final heard = heardForWord(
      phonemesPerWord: words,
      wordIndex: 3,
      emitted: 'بسماللهالرحمنكتب',
    );
    expect(heard, 'كتب');

    await t.pumpWidget(_page(expected: expected, heard: heard));
    await t.pumpAndSettle();

    final rect = t.getRect(
      find
          .descendant(of: find.byType(ReciteMushaf), matching: find.byType(RichText))
          .first,
    );
    await t.tapAt(Offset(rect.right - 12, rect.top + 20));
    await t.pumpAndSettle();

    expect(find.byType(ReciteCorrectionSheet), findsOneWidget);
    // "Terdengar" opsional: disembunyikan sampai user minta.
    expect(find.text('كتب'), findsNothing);
    await t.tap(find.text('Lihat yang terdengar'));
    await t.pumpAndSettle();
    expect(find.text('كتب'), findsOneWidget);
    expect(find.text('tidak terdengar'), findsNothing);
  });

  testWidgets('fonem mentah tampil sebagai satu teks tersambung', (t) async {
    // Fonem الرحيم dengan penanda madd: tanpa perapian, `ۦ` tampil sebagai
    // potongan terpisah dan memutus shaping.
    const raw = 'ررَحِۦۦۦۦم';

    await t.pumpWidget(_page(expected: 'الرحيم', heard: raw));
    await t.pumpAndSettle();

    final rect = t.getRect(
      find
          .descendant(of: find.byType(ReciteMushaf), matching: find.byType(RichText))
          .first,
    );
    await t.tapAt(Offset(rect.right - 12, rect.top + 20));
    await t.pumpAndSettle();

    await t.tap(find.text('Lihat yang terdengar'));
    await t.pumpAndSettle();

    final shown = displayHeard(raw);
    expect(shown, 'رَحِيم');
    // Satu Text saja, bukan per-token.
    expect(find.text(shown), findsOneWidget);
    final texts = t
        .widgetList<Text>(
          find.descendant(
            of: find.byType(ReciteCorrectionSheet),
            matching: find.byType(Text),
          ),
        )
        .map((w) => w.data)
        .toList();
    expect(texts.where((s) => s == shown).length, 1);
    expect(texts.any((s) => s != null && s.contains('\u06E6')), isFalse);
    expect(texts.any((s) => s != null && s.contains('\u0621')), isFalse);
  });

  testWidgets('kata yang benar-benar dilewati menampilkan "tidak terdengar"',
      (t) async {
    final heard = heardForWord(
      phonemesPerWord: const ['بسم', 'الله', 'الرحمن'],
      wordIndex: 1,
      emitted: 'بسمالرحمن',
    );
    expect(heard, isNull);

    await t.pumpWidget(_page(expected: 'الله', heard: heard));
    await t.pumpAndSettle();

    final rect = t.getRect(
      find
          .descendant(of: find.byType(ReciteMushaf), matching: find.byType(RichText))
          .first,
    );
    await t.tapAt(Offset(rect.right - 12, rect.top + 20));
    await t.pumpAndSettle();

    // Tanpa bunyi sama sekali: tidak ada bagian "Terdengar" untuk dibuka.
    expect(find.text('Lihat yang terdengar'), findsNothing);
    expect(find.textContaining('belum terbaca'), findsOneWidget);
  });

  testWidgets('percobaan kedua menampilkan bunyi percobaan kedua', (t) async {
    // Alur halaman: kata merah dicatat saat dinilai, lalu Ulangi me-rewind
    // snapshot. Sheet harus memakai bunyi percobaan terakhir.
    final snap = AsrSnapshot();
    var heard = 'ججا';

    await t.pumpWidget(
      MaterialApp(
        home: QuranThemeScope(
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: 400,
                height: 600,
                child: Column(
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        // Percobaan 2: kata dinilai merah lagi dengan bunyi lain.
                        snap.rewind(forgetWords: [1]);
                        heard = 'كَتَبَ';
                        snap.recordHeard(1, heard);
                      }),
                      child: const Text('ulangi'),
                    ),
                    Expanded(
                      child: ReciteMushaf(
                        verses: [_verse('بسم الله الرحمن')],
                        matched: const {},
                        missed: const {1},
                        activeVerse: 0,
                        onWordTap: (id) => showReciteCorrectionSheet(
                          context,
                          expected: 'الله',
                          heard: snap.hasHeard(id) ? snap.heardOf(id) : heard,
                          dark: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    // Percobaan 1: "الله" terbaca "ججا".
    snap.recordHeard(1, 'ججا');

    await t.tap(find.text('ulangi'));
    await t.pumpAndSettle();

    final rect = t.getRect(
      find
          .descendant(of: find.byType(ReciteMushaf), matching: find.byType(RichText))
          .first,
    );
    await t.tapAt(Offset(rect.right - 12, rect.top + 20));
    await t.pumpAndSettle();

    expect(find.byType(ReciteCorrectionSheet), findsOneWidget);
    await t.tap(find.text('Lihat yang terdengar'));
    await t.pumpAndSettle();
    expect(find.text('كَتَبَ'), findsOneWidget);
    expect(find.text('ججا'), findsNothing);
  });
}
