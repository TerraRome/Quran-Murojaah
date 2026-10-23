import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/data/quran_tokens.dart';
import 'package:quran/Quran/murojaah/presentation/widgets/murojaah_progress_header.dart';
import 'package:quran/Quran/murojaah/progress/activity_entry.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entri hari ini; `verses` ayat mulai dari 1.
ActivityEntry _today(int verses, {DateTime? at, int surah = 1}) =>
    ActivityEntry(
      at: at ?? DateTime.now(),
      surahNumber: surah,
      fromVerse: 1,
      toVerse: verses,
      accuracy: 1,
    );

Future<MurojaahProgressController> _controller(List<ActivityEntry> seed) async {
  final controller = MurojaahProgressController(
    store: MemoryActivityStore(seed),
  );
  await controller.load();
  return controller;
}

Widget _app(MurojaahProgressController progress, {bool dark = false}) =>
    MaterialApp(
      theme: QuranTokens.themeData(dark),
      home: Scaffold(
        backgroundColor: QuranTokens.background(dark),
        body: MurojaahProgressHeader(progress: progress),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpSmall(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets('log kosong: ajakan mulai, tanpa deretan nol, tanpa overflow', (
    tester,
  ) async {
    final progress = await _controller(const []);
    await pumpSmall(tester, _app(progress));

    expect(find.text('Belum ada bacaan'), findsOneWidget);
    expect(find.text('Mulai dari satu ayat'), findsOneWidget);
    expect(find.text('Pilih surat di bawah untuk mulai.'), findsOneWidget);
    // Bukan angka nol yang menghakimi.
    expect(find.textContaining('0 hari'), findsNothing);
    expect(find.textContaining('0/'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('4 dari 15 ayat tampil sebagai angka target', (tester) async {
    final progress = await _controller([_today(4)]);
    await pumpSmall(tester, _app(progress));

    expect(find.text('4 dari 15 ayat'), findsOneWidget);
    expect(find.text('4/15'), findsOneWidget);
    expect(find.text('Sisa 11 ayat lagi'), findsOneWidget);
    expect(find.text('Target hari ini tercapai'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('target tercapai ditandai ikon centang + teks', (tester) async {
    final progress = await _controller([_today(15)]);
    await pumpSmall(tester, _app(progress));

    expect(find.text('Target hari ini tercapai'), findsOneWidget);
    expect(find.text('15 dari 15 ayat'), findsOneWidget);
    // Penanda bentuk, bukan hanya warna. Dua centang: cincin + hari ini di
    // kalender (hari ini juga aktif).
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('streak dan level/XP sesuai snapshot', (tester) async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final progress = await _controller([
      _today(4, at: yesterday),
      _today(4, at: now),
    ]);
    await pumpSmall(tester, _app(progress));

    expect(find.text('2 hari berturut-turut'), findsOneWidget);
    expect(find.text('Level 1 · 40/200 XP'), findsOneWidget);
    expect(find.text('Total 40 XP'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tombol Atur target ≥48px, tidak ada target sentuh kecil', (
    tester,
  ) async {
    final progress = await _controller([_today(4)]);
    await pumpSmall(tester, _app(progress));

    // Satu-satunya elemen interaktif: tombol "Atur target".
    final button = find.widgetWithText(TextButton, 'Atur target');
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    expect(find.byType(IconButton), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets('render bersih mode ${dark ? 'gelap' : 'terang'} 360x640', (
      tester,
    ) async {
      final progress = await _controller([_today(15)]);
      await pumpSmall(tester, _app(progress, dark: dark));

      expect(find.byType(MurojaahProgressHeader), findsOneWidget);
      expect(find.text('Target hari ini tercapai'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('placeholder ringan saat log belum dimuat', (tester) async {
    // Belum dipanggil load(): isLoaded false.
    final progress = MurojaahProgressController(
      store: MemoryActivityStore([_today(4)]),
    );
    await pumpSmall(tester, _app(progress));

    expect(find.text('Belum ada bacaan'), findsNothing);
    expect(find.textContaining('dari'), findsNothing);
    expect(tester.takeException(), isNull);
    progress.dispose();
  });

  testWidgets('tombol Peta hafalan berikon, berlabel, dan ≥48px', (
    tester,
  ) async {
    final progress = await _controller(const []);
    await pumpSmall(tester, _app(progress));

    expect(find.text('Peta hafalan'), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Peta hafalan')).height,
      greaterThanOrEqualTo(48),
    );
  });
}
