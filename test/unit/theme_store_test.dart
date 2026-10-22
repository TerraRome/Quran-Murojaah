import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/data/theme_store.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Membaca `dark` dari scope dan menampilkannya sebagai teks.
class _DarkProbe extends StatelessWidget {
  const _DarkProbe();

  @override
  Widget build(BuildContext context) => Text(
    QuranThemeScope.darkOf(context) ? 'gelap' : 'terang',
    textDirection: TextDirection.ltr,
  );
}

Widget _host(QuranThemeController controller) => AnimatedBuilder(
  animation: controller,
  builder: (context, _) => MaterialApp(
    theme: ThemeData(brightness: Brightness.light),
    darkTheme: ThemeData(brightness: Brightness.dark),
    themeMode: controller.dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(
      body: Text(
        controller.dark ? 'gelap' : 'terang',
        textDirection: TextDirection.ltr,
      ),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('default terang bila belum pernah memilih', () async {
    final controller = QuranThemeController();
    expect(controller.dark, isFalse);
    await controller.load();
    expect(controller.dark, isFalse);
  });

  test('toggle menyimpan pilihan gelap ke prefs', () async {
    final controller = QuranThemeController();
    await controller.load();
    controller.toggle();

    expect(controller.dark, isTrue);
    // toggle menulis tanpa ditunggu; beri kesempatan microtask selesai.
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ThemeStore.keyDark), isTrue);
  });

  test('pilihan gelap dipulihkan saat startup (tidak hilang saat restart)', () async {
    SharedPreferences.setMockInitialValues({ThemeStore.keyDark: true});
    final controller = QuranThemeController();
    await controller.load();
    expect(controller.dark, isTrue);
  });

  test('toggle dua kali kembali terang dan tersimpan', () async {
    final controller = QuranThemeController();
    await controller.load();
    controller.toggle();
    controller.toggle();
    await Future<void>.delayed(Duration.zero);
    expect(controller.dark, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ThemeStore.keyDark), isFalse);
  });

  test('load juga memulihkan ukuran font', () async {
    SharedPreferences.setMockInitialValues({
      'quran_font_size_arabic': 22.0,
      'quran_font_size_translation': 18.0,
    });
    final controller = QuranThemeController();
    await controller.load();
    expect(controller.arabicFontSize, 22.0);
    expect(controller.translationFontSize, 18.0);
  });

  test('prefs rusak: tetap terang, tidak melempar', () async {
    SharedPreferences.setMockInitialValues({'quran_theme_dark': 'bukan bool'});
    final controller = QuranThemeController();
    await controller.load();
    expect(controller.dark, isFalse);
  });

  testWidgets('tema aplikasi ikut berubah setelah toggle', (tester) async {
    final controller = QuranThemeController();
    await controller.load();
    await tester.pumpWidget(_host(controller));

    expect(find.text('terang'), findsOneWidget);

    controller.toggle();
    await tester.pumpAndSettle();

    expect(find.text('gelap'), findsOneWidget);
    expect(find.text('terang'), findsNothing);
  });

  testWidgets('QuranThemeScope memulihkan gelap saat startup', (tester) async {
    SharedPreferences.setMockInitialValues({ThemeStore.keyDark: true});
    await tester.pumpWidget(
      const MaterialApp(
        home: QuranThemeScope(child: Scaffold(body: _DarkProbe())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('gelap'), findsOneWidget);
  });

  testWidgets('QuranThemeScope mulai terang bila prefs kosong', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: QuranThemeScope(child: Scaffold(body: _DarkProbe())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('terang'), findsOneWidget);
  });
}
