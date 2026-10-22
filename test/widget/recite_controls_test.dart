import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/recite/recite_murojaah_service.dart';
import 'package:quran/Quran/murojaah/recite/widgets/recite_controls.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: QuranThemeScope(
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('mikrofon berlabel "Mulai membaca" saat diam', (t) async {
    await t.pumpWidget(_wrap(
      ReciteMicButton(
        listening: false,
        enabled: true,
        dark: false,
        onTap: () {},
      ),
    ));
    expect(find.text('Mulai membaca'), findsOneWidget);
    expect(find.bySemanticsLabel('Mulai membaca'), findsOneWidget);
  });

  testWidgets('mikrofon berlabel "Berhenti" saat mendengarkan', (t) async {
    await t.pumpWidget(_wrap(
      ReciteMicButton(
        listening: true,
        enabled: true,
        dark: false,
        onTap: () {},
      ),
    ));
    expect(find.text('Berhenti'), findsOneWidget);
    expect(find.bySemanticsLabel('Berhenti membaca'), findsOneWidget);
  });

  testWidgets('label tombol aksi minimal 14px', (t) async {
    await t.pumpWidget(_wrap(
      ReciteActionButton(
        icon: Icons.replay,
        label: 'Mulai dari awal',
        dark: false,
        onTap: () {},
      ),
    ));
    final text = t.widget<Text>(find.text('Mulai dari awal'));
    expect(text.style!.fontSize, greaterThanOrEqualTo(14));
  });

  testWidgets('label kompak juga minimal 14px dan area ketuk ≥ 48',
      (t) async {
    await t.pumpWidget(_wrap(
      ReciteActionButton(
        icon: Icons.visibility_outlined,
        label: 'Intip kata',
        dark: false,
        compact: true,
        onTap: () {},
      ),
    ));
    final text = t.widget<Text>(find.text('Intip kata'));
    expect(text.style!.fontSize, greaterThanOrEqualTo(14));
    final size = t.getSize(
      find.ancestor(
        of: find.text('Intip kata'),
        matching: find.byType(InkWell),
      ),
    );
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('status memakai kalimat biasa, bukan istilah mesin', (t) async {
    await t.pumpWidget(_wrap(
      ReciteStatusChip(
        status: ReciteMurojaahStatus.listening,
        message: null,
        dark: false,
        showHint: true,
      ),
    ));
    expect(find.text('Sedang mendengarkan'), findsOneWidget);
    final text = t.widget<Text>(find.text('Sedang mendengarkan'));
    expect(text.style!.fontSize, greaterThanOrEqualTo(16));
    final hint = t.widget<Text>(find.text('Baca dengan suara biasa.'));
    expect(hint.style!.fontSize, greaterThanOrEqualTo(14));
  });
}
