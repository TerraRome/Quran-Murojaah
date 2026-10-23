import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/shalat/application/location_provider.dart';
import 'package:quran/Quran/shalat/application/location_service.dart';
import 'package:quran/Quran/shalat/application/shalat_controller.dart';
import 'package:quran/Quran/shalat/data/datasources/shalat_local_datasource.dart';
import 'package:quran/Quran/shalat/data/datasources/shalat_remote_datasource.dart';
import 'package:quran/Quran/shalat/data/models/jadwal_shalat_model.dart';
import 'package:quran/Quran/shalat/data/models/waktu_shalat_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Fakes ────────────────────────────────────────────────────────────────────

/// Penyedia lokasi palsu: satu hasil yang sudah ditentukan.
class _FakeProvider implements LocationProvider {
  _FakeProvider(this.outcome, {this.granted = false});

  final LocationOutcome outcome;
  final bool granted;
  int calls = 0;
  int appSettingsCalls = 0;
  int locationSettingsCalls = 0;

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<LocationOutcome> currentLocation() async {
    calls++;
    return outcome;
  }

  @override
  Future<void> openAppSettings() async => appSettingsCalls++;

  @override
  Future<void> openLocationSettings() async => locationSettingsCalls++;
}

/// Reverse geocoder palsu yang tidak menyentuh plugin.
class _FakeGeocoder extends LocationService {
  _FakeGeocoder(this.administrativeArea, this.locality);

  final String? administrativeArea;
  final String? locality;

  @override
  Future<PlaceNames?> reverseGeocode(double lat, double lng) async =>
      PlaceNames(administrativeArea: administrativeArea, locality: locality);
}

/// Data source palsu dengan provinsi/kabkota tetap.
class _FakeRemote implements ShalatRemoteDataSource {
  _FakeRemote({this.failJadwal = false});

  final bool failJadwal;
  int jadwalCalls = 0;

  static const provinsi = ['DKI Jakarta', 'Jawa Barat'];

  @override
  Future<List<String>> getProvinsi() async => provinsi;

  @override
  Future<List<String>> getKabkota(String provinsi) async => switch (provinsi) {
        'DKI Jakarta' => ['KOTA JAKARTA PUSAT', 'KOTA JAKARTA BARAT'],
        'Jawa Barat' => ['KOTA BANDUNG'],
        _ => <String>[],
      };

  @override
  Future<JadwalShalatModel> getJadwalShalat({
    required String provinsi,
    required String kabkota,
    int? bulan,
    int? tahun,
  }) async {
    jadwalCalls++;
    if (failJadwal) throw const ShalatApiException('down');
    final now = DateTime.now();
    return JadwalShalatModel(
      provinsi: provinsi,
      kabkota: kabkota,
      bulan: bulan ?? now.month,
      tahun: tahun ?? now.year,
      bulanNama: 'Oktober',
      jadwal: [
        WaktuShalatModel(
          tanggal: now.day,
          tanggalLengkap:
              '${now.year}-${now.month.toString().padLeft(2, '0')}-'
              '${now.day.toString().padLeft(2, '0')}',
          hari: 'Jumat',
          imsak: '04:22',
          subuh: '04:32',
          terbit: '05:45',
          dhuha: '06:13',
          dzuhur: '11:53',
          ashar: '15:16',
          maghrib: '17:53',
          isya: '19:06',
        ),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ShalatController build({
    required LocationOutcome outcome,
    String? adminArea,
    String? locality,
    bool failJadwal = false,
    LocationService? geocoder,
    _FakeRemote? remote,
  }) =>
      ShalatController(
        remote: remote ?? _FakeRemote(failJadwal: failJadwal),
        local: ShalatLocalDataSource(),
        locationService: geocoder ?? _FakeGeocoder(adminArea, locality),
        locationProvider: _FakeProvider(outcome),
        connectivityCheck: () async => true,
      );

  // ── Pesan ramah untuk setiap sebab ────────────────────────────────────────

  group('copyForIssue', () {
    test('setiap sebab punya judul, isi, dan aksi', () {
      for (final issue in LocationIssue.values) {
        final copy = copyForIssue(issue);
        expect(copy.title, isNotEmpty, reason: '$issue');
        expect(copy.body, isNotEmpty, reason: '$issue');
        expect(copy.body, isNot(contains('Exception')), reason: '$issue');
      }
    });

    test('ditawarkan aksi yang tepat', () {
      expect(copyForIssue(LocationIssue.denied).action, LocationAction.retry);
      expect(
        copyForIssue(LocationIssue.deniedForever).action,
        LocationAction.openAppSettings,
      );
      expect(
        copyForIssue(LocationIssue.serviceOff).action,
        LocationAction.openLocationSettings,
      );
    });
  });

  // ── Alur izin ─────────────────────────────────────────────────────────────

  group('detectLocation', () {
    test('izin diberikan: lokasi terdeteksi lalu jadwal dimuat', () async {
      final controller = build(
        outcome: const LocationFix(-6.2, 106.8),
        adminArea: 'DKI Jakarta',
        locality: 'Jakarta Pusat',
      );
      await controller.init();
      expect(controller.value, isA<ShalatNeedLocation>());

      await controller.detectLocation();

      expect(controller.value, isA<ShalatLoaded>());
      final loaded = controller.value as ShalatLoaded;
      expect(loaded.jadwal.kabkota, 'KOTA JAKARTA PUSAT');
      expect(loaded.locationIssue, isNull);
      controller.dispose();
    });

    test('izin ditolak: pesan ramah, jadwal manual tetap bisa dipilih',
        () async {
      final controller = build(
        outcome: const LocationUnavailable(LocationIssue.denied),
      );
      await controller.init();
      await controller.detectLocation();

      final state = controller.value as ShalatNeedLocation;
      expect(state.issue, LocationIssue.denied);
      expect(copyForIssue(state.issue!).title, contains('Izin'));

      // Pilihan kota manual tetap berfungsi.
      await controller.setLokasi('Jawa Barat', 'KOTA BANDUNG');
      expect(controller.value, isA<ShalatLoaded>());
      controller.dispose();
    });

    test('ditolak permanen: tidak melempar, menawarkan pengaturan aplikasi',
        () async {
      final provider = _FakeProvider(
        const LocationUnavailable(LocationIssue.deniedForever),
      );
      final controller = ShalatController(
        remote: _FakeRemote(),
        local: ShalatLocalDataSource(),
        locationService: _FakeGeocoder('DKI Jakarta', 'Jakarta Pusat'),
        locationProvider: provider,
        connectivityCheck: () async => true,
      );
      await controller.init();
      await controller.detectLocation();

      final state = controller.value as ShalatNeedLocation;
      expect(state.issue, LocationIssue.deniedForever);
      expect(
        copyForIssue(state.issue!).action,
        LocationAction.openAppSettings,
      );

      await controller.openAppSettings();
      expect(provider.appSettingsCalls, 1);
      controller.dispose();
    });

    test('GPS mati: menawarkan pengaturan lokasi perangkat', () async {
      final provider = _FakeProvider(
        const LocationUnavailable(LocationIssue.serviceOff),
      );
      final controller = ShalatController(
        remote: _FakeRemote(),
        local: ShalatLocalDataSource(),
        locationService: _FakeGeocoder('DKI Jakarta', 'Jakarta Pusat'),
        locationProvider: provider,
        connectivityCheck: () async => true,
      );
      await controller.init();
      await controller.detectLocation();

      final state = controller.value as ShalatNeedLocation;
      expect(state.issue, LocationIssue.serviceOff);
      expect(
        copyForIssue(state.issue!).action,
        LocationAction.openLocationSettings,
      );

      await controller.openLocationSettings();
      expect(provider.locationSettingsCalls, 1);
      controller.dispose();
    });

    test('timeout: pesan ramah tanpa exception mentah', () async {
      final controller = build(
        outcome: const LocationUnavailable(LocationIssue.timeout),
      );
      await controller.init();
      await controller.detectLocation();

      final state = controller.value as ShalatNeedLocation;
      expect(state.issue, LocationIssue.timeout);
      expect(copyForIssue(state.issue!).body, contains('15 detik'));
      controller.dispose();
    });

    test('gagal tak terduga: tetap pesan ramah', () async {
      final controller = build(
        outcome: const LocationUnavailable(LocationIssue.failed),
      );
      await controller.init();
      await controller.detectLocation();

      expect(
        (controller.value as ShalatNeedLocation).issue,
        LocationIssue.failed,
      );
      controller.dispose();
    });

    test('koordinat tidak dikenali: detail ramah + kota manual', () async {
      final controller = build(
        outcome: const LocationFix(0, 0),
        adminArea: 'Antah Berantah',
        locality: 'Entah',
      );
      await controller.init();
      await controller.detectLocation();

      final state = controller.value as ShalatNeedLocation;
      expect(state.issue, LocationIssue.failed);
      expect(state.detail, contains('Pilih kota manual'));
      controller.dispose();
    });

    test('gagal saat jadwal sudah tampil: jadwal lama dipertahankan', () async {
      final controller = build(
        outcome: const LocationUnavailable(LocationIssue.serviceOff),
      );
      await controller.init();
      await controller.setLokasi('DKI Jakarta', 'KOTA JAKARTA PUSAT');
      expect(controller.value, isA<ShalatLoaded>());

      await controller.detectLocation();

      final state = controller.value as ShalatLoaded;
      expect(state.jadwal.kabkota, 'KOTA JAKARTA PUSAT');
      expect(state.locationIssue, LocationIssue.serviceOff);
      controller.dispose();
    });
  });

  // ── Error jadwal tidak membocorkan exception ──────────────────────────────

  test('kegagalan jaringan tampil sebagai pesan ramah, bukan toString()',
      () async {
    final controller = build(
      outcome: const LocationFix(-6.2, 106.8),
      adminArea: 'DKI Jakarta',
      locality: 'Jakarta Pusat',
      failJadwal: true,
    );
    await controller.init();
    await controller.detectLocation();

    final state = controller.value;
    expect(state, isA<ShalatError>());
    final message = (state as ShalatError).message;
    expect(message, isNot(contains('Exception')));
    expect(message, isNotEmpty);
    controller.dispose();
  });
}
