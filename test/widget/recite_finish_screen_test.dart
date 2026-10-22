import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/data/quran_tokens.dart';
import 'package:quran/Quran/murojaah/progress/record_result.dart';
import 'package:quran/Quran/murojaah/recite/widgets/recite_finish_screen.dart';

/// Layar penuh: ukuran tinggi cukup supaya semua tombol terlihat.
Widget _app({
  bool dark = false,
  bool reduceMotion = false,
  String surahName = 'Al-Fatihah',
  int versesDone = 7,
  int totalVerses = 7,
  int accuracyPercent = 92,
  int peekCount = 1,
  RecordResult result = const RecordResult(
    xpGained: 35,
    newStreak: 4,
    newLevel: 2,
  ),
  bool surahComplete = true,
  VoidCallback? onContinue,
  VoidCallback? onPickSurah,
  VoidCallback? onRepeat,
}) {
  final screen = ReciteFinishScreen(
    surahName: surahName,
    versesDone: versesDone,
    totalVerses: totalVerses,
    accuracyPercent: accuracyPercent,
    peekCount: peekCount,
    result: result,
    surahComplete: surahComplete,
    onContinue: onContinue ?? () {},
    onPickSurah: onPickSurah ?? () {},
    onRepeat: onRepeat ?? () {},
  );

  return MaterialApp(
    theme: QuranTokens.themeData(dark),
    home: Scaffold(
      backgroundColor: QuranTokens.background(dark),
      body: reduceMotion
          ? Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: screen,
              ),
            )
          : screen,
    ),
  );
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget app, {
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('surah tamat: judul + tiga tombol', (tester) async {
    await pumpScreen(tester, _app());
    expect(find.textContaining('Al-Fatihah'), findsWidgets);
    expect(find.text('Surah Al-Fatihah selesai'), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);
    expect(find.text('Ulangi surah'), findsOneWidget);
    expect(find.text('Pilih surah lain'), findsOneWidget);
  });

  testWidgets('berhenti manual: tanpa tombol ulangi', (tester) async {
    await pumpScreen(tester, _app(surahComplete: false, versesDone: 3));
    expect(find.text('Ulangi surah'), findsNothing);
    expect(find.text('Lanjut'), findsOneWidget);
    expect(find.text('Pilih surah lain'), findsOneWidget);
    expect(find.text('Latihan hari ini tersimpan'), findsOneWidget);
  });

  testWidgets('tanpa penanda: tidak ada baris pencapaian', (tester) async {
    await pumpScreen(tester, _app());
    expect(find.text('Streak naik'), findsNothing);
    expect(find.text('Target hari ini tercapai'), findsNothing);
    expect(find.textContaining('Level naik'), findsNothing);
  });

  testWidgets('streak naik muncul dengan ikon', (tester) async {
    await pumpScreen(
      tester,
      _app(result: const RecordResult(streakIncreased: true, newStreak: 4)),
    );
    expect(find.text('Streak naik'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsWidgets);
    expect(find.text('Target hari ini tercapai'), findsNothing);
  });

  testWidgets('target harian tercapai muncul dengan ikon', (tester) async {
    await pumpScreen(
      tester,
      _app(result: const RecordResult(goalJustReached: true)),
    );
    expect(find.text('Target hari ini tercapai'), findsOneWidget);
    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
  });

  testWidgets('level naik menampilkan level baru', (tester) async {
    await pumpScreen(
      tester,
      _app(result: const RecordResult(newLevel: 5, leveledUp: true)),
    );
    expect(find.text('Level naik ke 5'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);
  });

  testWidgets('akurasi rendah memakai kalimat latihan, akurasi tinggi tidak', (
    tester,
  ) async {
    await pumpScreen(tester, _app(accuracyPercent: 55));
    expect(find.textContaining('Terus berlatih'), findsOneWidget);
    // Tidak menghakimi.
    expect(find.textContaining('gagal'), findsNothing);
    expect(find.textContaining('salah'), findsNothing);

    await pumpScreen(tester, _app(accuracyPercent: 96));
    expect(find.textContaining('Terus berlatih'), findsNothing);
  });

  testWidgets('reduce motion: skala 1.0 tanpa animasi berjalan', (
    tester,
  ) async {
    await pumpScreen(tester, _app(reduceMotion: true), settle: false);
    await tester.pump();

    final scale = tester.widget<Transform>(
      find.byKey(ReciteFinishScreen.celebrationKey),
    );
    expect(scale.transform.storage[0], moreOrLessEquals(1.0));
    expect(
      tester.widget<Transform>(find.byKey(ReciteFinishScreen.xpKey)),
      isA<Transform>(),
    );
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('tanpa reduce motion: perayaan mulai dari skala < 1', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 50));

    final scale = tester.widget<Transform>(
      find.byKey(ReciteFinishScreen.celebrationKey),
    );
    expect(scale.transform.storage[0], lessThan(1.0));

    await tester.pumpAndSettle();
    final settled = tester.widget<Transform>(
      find.byKey(ReciteFinishScreen.celebrationKey),
    );
    expect(settled.transform.storage[0], moreOrLessEquals(1.0));
  });

  testWidgets('ketiga tombol memanggil callback-nya', (tester) async {
    var continued = 0;
    var picked = 0;
    var repeated = 0;
    await pumpScreen(
      tester,
      _app(
        onContinue: () => continued++,
        onPickSurah: () => picked++,
        onRepeat: () => repeated++,
      ),
    );

    await tester.ensureVisible(find.text('Lanjut'));
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    await tester.ensureVisible(find.text('Ulangi surah'));
    await tester.tap(find.text('Ulangi surah'));
    await tester.pump();
    await tester.ensureVisible(find.text('Pilih surah lain'));
    await tester.tap(find.text('Pilih surah lain'));
    await tester.pump();

    expect(continued, 1);
    expect(repeated, 1);
    expect(picked, 1);
  });

  testWidgets('mode terang dan gelap render tanpa error', (tester) async {
    await pumpScreen(tester, _app());
    expect(tester.takeException(), isNull);
    await pumpScreen(tester, _app(dark: true));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ringkasan satu kalimat untuk pembaca layar', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpScreen(tester, _app());

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Surah Al-Fatihah selesai\. 7 dari 7 ayat, akurasi 92 persen, '
          r'1 kali intip, 35 XP, streak 4 hari\.',
        ),
      ),
      findsOneWidget,
    );
    // Tombol tetap terbaca sendiri.
    expect(find.bySemanticsLabel('Lanjut'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('semua tombol setinggi minimal 48', (tester) async {
    await pumpScreen(tester, _app());
    for (final label in ['Lanjut', 'Ulangi surah', 'Pilih surah lain']) {
      final size = tester.getSize(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
  });
}
