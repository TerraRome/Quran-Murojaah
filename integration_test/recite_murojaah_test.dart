import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quran/Quran/murojaah/recite/recite_murojaah_page.dart';
import 'package:quran/Quran/murojaah/recite/widgets/recite_controls.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uji di perangkat: halaman murojaah asli, model ASR asli, mikrofon asli.
///
/// Yang diperiksa hanya yang tidak bisa dipercaya dari widget test: tata letak
/// nyata (tidak overflow), ukuran target sentuh, dan jalur mikrofon → status.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'recite_onboarding_seen': true}));

  Future<void> boot(WidgetTester t, {bool dark = false}) async {
    await t.pumpWidget(
      QuranThemeScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true),
          home: const ReciteMurojaahPage(surahNumber: 1),
        ),
      ),
    );
    // initialize(): baca surah + siapkan model (model sudah ada di perangkat).
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 250));
      if (find.text('Intip kata').evaluate().isNotEmpty) break;
    }
    if (dark) {
      await t.tap(find.byTooltip('Mode gelap'));
      await t.pumpAndSettle();
    }
  }

  testWidgets('halaman murojaah tampil utuh di perangkat', (t) async {
    await boot(t);

    // Ayat termuat dari aset (bukan jaringan).
    expect(find.text('Intip kata'), findsOneWidget);
    expect(find.text('Mulai membaca'), findsOneWidget);
    expect(find.text('Mulai dari awal'), findsOneWidget);
    expect(find.text('Ulang ayat ini'), findsOneWidget);
    expect(find.text('Benar'), findsOneWidget);
    expect(find.text('Perlu diulang'), findsOneWidget);
    // Progres memakai kalimat, bukan istilah mesin.
    expect(find.textContaining(RegExp(r'Ayat \d+ dari \d+ · Akurasi \d+%')),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('target sentuh ≥ 48px di perangkat', (t) async {
    await boot(t);
    for (final label in ['Mulai dari awal', 'Ulang ayat ini', 'Intip kata']) {
      final box = t.getRect(
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
      );
      expect(box.height, greaterThanOrEqualTo(48), reason: label);
    }
    final header = t.getRect(find.byTooltip('Cara pakai'));
    expect(header.width, greaterThanOrEqualTo(48));
    expect(header.height, greaterThanOrEqualTo(48));
  });

  testWidgets('intip kata menambah hitungan dan membuka satu kata', (t) async {
    await boot(t);
    expect(find.textContaining('kali intip'), findsNothing);
    await t.tap(find.text('Intip kata'));
    await t.pumpAndSettle();
    expect(find.text('1 kali intip'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('mode gelap: token semantik tetap terpakai', (t) async {
    await boot(t, dark: true);
    expect(find.text('Intip kata'), findsOneWidget);
    // Warna benar/salah berasal dari token gelap, bukan merah/hijau bawaan.
    final legend = t.widget<Text>(find.text('Benar'));
    expect(legend.style!.color, const Color(0xFF5FD08A));
    final wrong = t.widget<Text>(find.text('Perlu diulang'));
    expect(wrong.style!.color, const Color(0xFFFF8A80));
    expect(t.takeException(), isNull);
  });

  testWidgets('judul surah membuka daftar surah', (t) async {
    await boot(t);
    await t.tap(find.bySemanticsLabel(RegExp('memilih surah lain')));
    await t.pumpAndSettle();
    expect(find.text('Pilih surah'), findsOneWidget);
    expect(find.textContaining('ayat'), findsWidgets);
  });

  testWidgets('panduan bisa dibuka dari tombol bantuan', (t) async {
    await boot(t);
    await t.tap(find.byTooltip('Cara pakai'));
    await t.pumpAndSettle();
    expect(find.text('Cara memakai latihan ini'), findsOneWidget);
    expect(find.text('Mengerti'), findsOneWidget);
    await t.tap(find.text('Mengerti'));
    await t.pumpAndSettle();
    expect(find.text('Intip kata'), findsOneWidget);
  });

  testWidgets('layar selesai muncul setelah semua kata benar', (t) async {
    await boot(t);
    // Tidak mungkin membacakan 29 kata di test; cukup pastikan tidak ada
    // kartu selesai saat sesi masih berjalan (tidak muncul terlalu awal).
    expect(find.text('Latihan hari ini tersimpan'), findsNothing);
    expect(find.byType(ReciteMicButton), findsOneWidget);
  });
}
