import 'package:flutter/material.dart';
import 'package:quran/Quran/presentation/pages/settings_page.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap() => QuranThemeScope(
        child: MaterialApp(home: const SettingsPage()),
      );

  testWidgets('menampilkan judul Pengaturan, 4 preset, tanpa slider',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    for (final l in ['Kecil', 'Sedang', 'Besar', 'Sangat Besar']) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.text('Tampilkan latin'), findsOneWidget);
    expect(find.text('Tampilkan terjemahan'), findsOneWidget);
  });

  testWidgets('default: Sedang terpilih; memilih Besar menyimpan ukuran',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    ChoiceChip chip(String l) =>
        tester.widget(find.widgetWithText(ChoiceChip, l));
    expect(chip('Sedang').selected, isTrue);
    expect(tester.getSize(find.widgetWithText(ChoiceChip, 'Besar')).height,
        greaterThanOrEqualTo(48));

    await tester.tap(find.text('Besar'));
    await tester.pumpAndSettle();
    expect(chip('Besar').selected, isTrue);
    expect(chip('Sedang').selected, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('quran_font_size_arabic'), 36);
    expect(prefs.getDouble('quran_font_size_latin'), 20);
    expect(prefs.getDouble('quran_font_size_translation'), 22);
  });

  testWidgets('switch latin mati tersimpan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tampilkan latin'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('quran_show_latin'), isFalse);
  });

  testWidgets('preview menampilkan teks Arab dan terjemahan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(
      find.text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'),
      findsOneWidget,
    );
    expect(find.text('Bismillāhir-raḥmānir-raḥīm(i).'), findsOneWidget);
    expect(
      find.text(
        'Dengan nama Allah Yang Maha Pengasih, Maha Penyayang.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tombol Reset ada', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Reset'), findsOneWidget);
  });
}
