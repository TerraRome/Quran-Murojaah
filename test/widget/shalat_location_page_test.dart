import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/data/quran_tokens.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:quran/Quran/shalat/application/location_provider.dart';
import 'package:quran/Quran/shalat/application/location_service.dart';
import 'package:quran/Quran/shalat/application/shalat_controller.dart';
import 'package:quran/Quran/shalat/data/datasources/shalat_local_datasource.dart';
import 'package:quran/Quran/shalat/data/datasources/shalat_remote_datasource.dart';
import 'package:quran/Quran/shalat/data/models/jadwal_shalat_model.dart';
import 'package:quran/Quran/shalat/presentation/pages/shalat_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeProvider implements LocationProvider {
  _FakeProvider({this.granted = false, this.issue = LocationIssue.denied});

  final bool granted;
  final LocationIssue issue;
  int calls = 0;

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<LocationOutcome> currentLocation() async {
    calls++;
    return LocationUnavailable(issue);
  }

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

class _FakeRemote implements ShalatRemoteDataSource {
  @override
  Future<List<String>> getProvinsi() async => const ['DKI Jakarta'];

  @override
  Future<List<String>> getKabkota(String provinsi) async =>
      const ['KOTA JAKARTA PUSAT'];

  @override
  Future<JadwalShalatModel> getJadwalShalat({
    required String provinsi,
    required String kabkota,
    int? bulan,
    int? tahun,
  }) async =>
      throw const ShalatApiException('tidak dipakai di test ini');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ShalatController> pumpPage(
    WidgetTester tester, {
    required _FakeProvider provider,
  }) async {
    final controller = ShalatController(
      remote: _FakeRemote(),
      local: ShalatLocalDataSource(),
      locationService: LocationService(),
      locationProvider: provider,
      connectivityCheck: () async => true,
    );
    await tester.pumpWidget(
      QuranThemeScope(
        child: MaterialApp(
          theme: QuranTokens.themeData(false),
          home: ShalatPage(controller: controller),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('izin ditolak: pesan ramah + dua tombol, tanpa teks exception',
      (tester) async {
    final controller = await pumpPage(tester, provider: _FakeProvider());
    await controller.detectLocation();
    await tester.pump();

    expect(find.text('Izin lokasi belum diberikan'), findsOneWidget);
    expect(find.text('Coba Deteksi Lagi'), findsOneWidget);
    expect(find.text('Pilih Kota Manual'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);

    controller.dispose();
  });

  testWidgets('ditolak permanen: menawarkan pengaturan aplikasi',
      (tester) async {
    final controller = await pumpPage(
      tester,
      provider: _FakeProvider(issue: LocationIssue.deniedForever),
    );
    await controller.detectLocation();
    await tester.pump();

    expect(find.text('Izin lokasi diblokir'), findsOneWidget);
    expect(find.text('Buka Pengaturan Aplikasi'), findsOneWidget);
    expect(find.text('Pilih Kota Manual'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('GPS mati: menawarkan pengaturan lokasi perangkat',
      (tester) async {
    final controller = await pumpPage(
      tester,
      provider: _FakeProvider(issue: LocationIssue.serviceOff),
    );
    await controller.detectLocation();
    await tester.pump();

    expect(find.text('Lokasi perangkat mati'), findsOneWidget);
    expect(find.text('Buka Pengaturan Lokasi'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('alasan dijelaskan sebelum dialog izin sistem', (tester) async {
    final provider = _FakeProvider();
    final controller = await pumpPage(tester, provider: provider);

    await tester.tap(find.text('Gunakan Lokasi GPS'));
    await tester.pumpAndSettle();

    expect(find.text('Kenapa perlu lokasi?'), findsOneWidget);
    expect(find.text('Lanjutkan'), findsOneWidget);
    // Belum ada permintaan izin sebelum pengguna setuju.
    expect(provider.calls, 0);

    await tester.tap(find.text('Lanjutkan'));
    await tester.pumpAndSettle();

    expect(provider.calls, 1);
    expect(find.text('Izin lokasi belum diberikan'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('izin sudah dipegang: tanpa dialog penjelasan', (tester) async {
    final provider = _FakeProvider(granted: true);
    final controller = await pumpPage(tester, provider: provider);

    await tester.tap(find.text('Gunakan Lokasi GPS'));
    await tester.pumpAndSettle();

    expect(find.text('Kenapa perlu lokasi?'), findsNothing);
    expect(provider.calls, 1);

    controller.dispose();
  });

  testWidgets('teks baru minimal 14px dan tombol minimal 48px',
      (tester) async {
    final controller = await pumpPage(tester, provider: _FakeProvider());
    await controller.detectLocation();
    await tester.pump();

    for (final label in [
      'Izin lokasi belum diberikan',
      'Coba Deteksi Lagi',
      'Pilih Kota Manual',
    ]) {
      // Ukuran efektif (termasuk yang diwarisi dari tema tombol).
      final rich = tester.widget<RichText>(
        find.descendant(of: find.text(label), matching: find.byType(RichText)),
      );
      expect(
        rich.text.style?.fontSize,
        greaterThanOrEqualTo(14),
        reason: label,
      );
    }

    for (final label in ['Coba Deteksi Lagi', 'Pilih Kota Manual']) {
      final size = tester.getSize(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }

    controller.dispose();
  });
}
