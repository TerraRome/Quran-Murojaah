import 'package:flutter/material.dart';
import 'package:flutter_portfolio/Quran/presentation/pages/font_size_settings.dart';
import 'package:flutter_portfolio/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap() => QuranThemeScope(
        child: MaterialApp(home: const FontSizeSettings()),
      );

  testWidgets('menampilkan judul Pengaturan dan 2 slider', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.text('Ukuran Teks Arab'), findsOneWidget);
    expect(find.text('Ukuran Teks Terjemahan'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(2));
  });

  testWidgets('nilai default 18 (Arab) dan 16 (Terjemahan)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('18'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
  });

  testWidgets('preview menampilkan teks Arab dan terjemahan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(
      find.text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'),
      findsOneWidget,
    );
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
