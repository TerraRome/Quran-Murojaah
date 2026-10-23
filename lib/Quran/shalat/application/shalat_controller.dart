import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/datasources/shalat_local_datasource.dart';
import '../data/datasources/shalat_remote_datasource.dart';
import '../domain/entities/jadwal_shalat.dart';
import '../domain/entities/waktu_shalat.dart';
import 'adzan_notifications.dart';
import 'location_provider.dart';
import 'location_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

sealed class ShalatState {
  const ShalatState();
}

class ShalatLoading extends ShalatState {
  const ShalatLoading();
}

class ShalatNeedLocation extends ShalatState {
  const ShalatNeedLocation({this.issue, this.detail});

  /// Sebab lokasi tidak tersedia. Null = belum pernah mencoba mendeteksi.
  final LocationIssue? issue;

  /// Konteks tambahan yang ramah dibaca (mis. provinsi sudah terdeteksi).
  final String? detail;
}

class ShalatLoaded extends ShalatState {
  const ShalatLoaded({
    required this.jadwal,
    required this.today,
    required this.nextWaktu,
    required this.countdown,
    required this.notifEnabled,
    this.isOffline = false,
    this.locationIssue,
    this.notifMessage,
    this.koordinat,
  });

  final JadwalShalat jadwal;
  final WaktuShalat? today;

  /// Waktu shalat berikutnya hari ini. Null jika sudah Isya.
  final ShalatEntry? nextWaktu;

  /// Countdown ke waktu shalat berikutnya.
  final Duration countdown;

  final bool notifEnabled;
  final bool isOffline;

  /// Sebab deteksi lokasi terakhir gagal, padahal jadwal tetap tampil dari
  /// lokasi tersimpan. Null = tidak ada masalah.
  final LocationIssue? locationIssue;

  /// Pesan ramah seputar notifikasi (izin ditolak, alarm tidak eksak, gagal
  /// dipasang). Null = tidak ada yang perlu dikatakan.
  final String? notifMessage;

  /// Koordinat kota terpilih. Null = arah kiblat belum bisa dihitung.
  final ({double latitude, double longitude})? koordinat;

  String get lokasi => '${jadwal.kabkota}, ${jadwal.provinsi}';

  ShalatLoaded copyWith({
    JadwalShalat? jadwal,
    WaktuShalat? today,
    ShalatEntry? nextWaktu,
    bool clearNextWaktu = false,
    Duration? countdown,
    bool? notifEnabled,
    bool? isOffline,
    LocationIssue? locationIssue,
    bool clearLocationIssue = false,
    String? notifMessage,
    bool clearNotifMessage = false,
    ({double latitude, double longitude})? koordinat,
    bool clearKoordinat = false,
  }) => ShalatLoaded(
    jadwal: jadwal ?? this.jadwal,
    today: today ?? this.today,
    nextWaktu: clearNextWaktu ? null : nextWaktu ?? this.nextWaktu,
    countdown: countdown ?? this.countdown,
    notifEnabled: notifEnabled ?? this.notifEnabled,
    isOffline: isOffline ?? this.isOffline,
    locationIssue: clearLocationIssue
        ? null
        : locationIssue ?? this.locationIssue,
    notifMessage: clearNotifMessage ? null : notifMessage ?? this.notifMessage,
    koordinat: clearKoordinat ? null : koordinat ?? this.koordinat,
  );
}

class ShalatError extends ShalatState {
  const ShalatError(this.message);
  final String message;
}

// ── Controller ────────────────────────────────────────────────────────────────

/// Controller untuk fitur Jadwal Shalat.
///
/// Flow:
/// 1. Load lokasi tersimpan → jika ada, langsung fetch/cache jadwal.
/// 2. Jika tidak ada lokasi → [ShalatNeedLocation] untuk trigger GPS/manual.
/// 3. GPS: detect → reverse geocode → fuzzy match → simpan → fetch jadwal.
/// 4. Offline-first: cek koneksi → API → cache, fallback ke cache jika offline.
/// 5. Countdown: Timer.periodic setiap detik update countdown ke waktu berikutnya.
class ShalatController extends ValueNotifier<ShalatState> {
  ShalatController({
    required ShalatRemoteDataSource remote,
    required ShalatLocalDataSource local,
    required LocationService locationService,
    LocationProvider locationProvider = const GeolocatorLocationProvider(),
    Future<bool> Function()? connectivityCheck,
    AdzanNotifications? notifications,
  }) : _remote = remote,
       _local = local,
       _locationService = locationService,
       _locationProvider = locationProvider,
       _connectivityCheck = connectivityCheck,
       _notifications =
           notifications ?? const AdzanNotifications(PluginAdzanScheduler()),
       super(const ShalatLoading());

  final ShalatRemoteDataSource _remote;
  final ShalatLocalDataSource _local;
  final LocationService _locationService;
  final LocationProvider _locationProvider;

  /// Sumber status jaringan; bisa diganti di test supaya tidak butuh plugin.
  final Future<bool> Function()? _connectivityCheck;
  final AdzanNotifications _notifications;

  Timer? _countdownTimer;

  /// Nomor permintaan koordinat terakhir. Hasil geocode yang datang setelah
  /// pengguna memilih kota lain diabaikan (tidak menimpa hasil baru).
  int _koordinatRequest = 0;

  /// Cache in-memory untuk list provinsi dan kabkota.
  List<String>? _cachedProvinsi;
  final Map<String, List<String>> _cachedKabkota = {};

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    value = const ShalatLoading();
    final saved = await _local.getSavedLokasi();
    if (saved.provinsi != null && saved.kabkota != null) {
      await _loadJadwal(provinsi: saved.provinsi!, kabkota: saved.kabkota!);
    } else {
      value = const ShalatNeedLocation();
    }
  }

  // ── GPS detect ───────────────────────────────────────────────────────────

  /// Deteksi lokasi via GPS → reverse geocode → fuzzy match → load jadwal.
  ///
  /// Tidak pernah melempar dan tidak pernah mengosongkan jadwal yang sudah
  /// tampil: bila deteksi gagal padahal lokasi tersimpan ada, halaman tetap
  /// menampilkan jadwal dan hanya menambahkan catatan [ShalatLoaded.locationIssue].
  Future<void> detectLocation() async {
    final previous = value;
    final hasJadwal = previous is ShalatLoaded;
    if (!hasJadwal) value = const ShalatLoading();

    try {
      final provinsiList = await _getProvinsi();

      final outcome = await _locationProvider.currentLocation();
      if (outcome is LocationUnavailable) {
        _failLocation(outcome.issue, previous: previous);
        return;
      }
      final fix = outcome as LocationFix;

      final placemark = await _locationService.reverseGeocode(
        fix.latitude,
        fix.longitude,
      );

      final matchedProvinsi = _locationService.matchProvinsi(
        placemark?.administrativeArea,
        provinsiList,
      );

      if (matchedProvinsi == null) {
        _failLocation(
          LocationIssue.failed,
          previous: previous,
          detail: 'Kota tidak dikenali dari koordinat. Pilih kota manual.',
        );
        return;
      }

      final kabkotaList = await _getKabkota(matchedProvinsi);
      final matchedKabkota = _locationService.matchKabkota(
        placemark?.locality,
        placemark?.subAdministrativeArea,
        kabkotaList,
      );

      if (matchedKabkota == null) {
        _failLocation(
          LocationIssue.failed,
          previous: previous,
          detail:
              'Provinsi terdeteksi: $matchedProvinsi. '
              'Pilih kabupaten/kota manual.',
        );
        return;
      }

      await _local.saveLokasi(matchedProvinsi, matchedKabkota);
      // GPS mengalahkan geocode yang mungkin masih berjalan.
      _koordinatRequest++;
      await _local.saveKoordinat(fix.latitude, fix.longitude);
      await _loadJadwal(provinsi: matchedProvinsi, kabkota: matchedKabkota);
    } catch (_) {
      _failLocation(LocationIssue.failed, previous: previous);
    }
  }

  /// Apakah izin lokasi sudah dipegang. Dipakai halaman untuk menampilkan
  /// penjelasan sebelum dialog izin sistem muncul.
  Future<bool> hasLocationPermission() => _locationProvider.hasPermission();

  Future<void> openAppSettings() => _locationProvider.openAppSettings();

  Future<void> openLocationSettings() =>
      _locationProvider.openLocationSettings();

  void _failLocation(
    LocationIssue issue, {
    required ShalatState previous,
    String? detail,
  }) {
    if (previous is ShalatLoaded) {
      value = previous.copyWith(locationIssue: issue);
    } else {
      value = ShalatNeedLocation(issue: issue, detail: detail);
    }
  }

  // ── Manual lokasi ─────────────────────────────────────────────────────────

  Future<List<String>> getProvinsi() => _getProvinsi();

  Future<List<String>> getKabkota(String provinsi) => _getKabkota(provinsi);

  Future<void> setLokasi(String provinsi, String kabkota) async {
    final request = ++_koordinatRequest;
    await _local.saveLokasi(provinsi, kabkota);
    // Koordinat kota lama dibuang segera: arah kiblat tidak boleh menunjuk
    // kota sebelumnya selama geocoding berjalan.
    await _local.clearKoordinat();
    final state = value;
    if (state is ShalatLoaded) {
      value = state.copyWith(clearKoordinat: true);
    }

    // Koordinat hanya untuk arah kiblat. Gagal geocode = kiblat minta GPS,
    // jadwal shalat tetap jalan.
    final coords = await _locationService.coordinatesForCity(provinsi, kabkota);
    if (request != _koordinatRequest) return; // pengguna sudah pilih kota lain

    if (coords != null) {
      await _local.saveKoordinat(coords.latitude, coords.longitude);
    }
    await _loadJadwal(provinsi: provinsi, kabkota: kabkota);
  }

  /// Cari ulang koordinat kota tersimpan, mis. setelah sebelumnya offline.
  /// Tidak pernah melempar; gagal = arah kiblat tetap minta lokasi.
  Future<void> refreshKoordinat() async {
    final saved = await _local.getSavedLokasi();
    final provinsi = saved.provinsi;
    final kabkota = saved.kabkota;
    if (provinsi == null || kabkota == null) return;

    final request = ++_koordinatRequest;
    await _local.clearKoordinat();
    final state = value;
    if (state is ShalatLoaded) {
      value = state.copyWith(clearKoordinat: true);
    }

    final coords = await _locationService.coordinatesForCity(provinsi, kabkota);
    if (request != _koordinatRequest || coords == null) return;

    await _local.saveKoordinat(coords.latitude, coords.longitude);
    final current = value;
    if (current is ShalatLoaded) {
      value = current.copyWith(koordinat: coords);
    }
  }

  // ── Load jadwal ───────────────────────────────────────────────────────────

  Future<void> _loadJadwal({
    required String provinsi,
    required String kabkota,
    int? bulan,
    int? tahun,
  }) async {
    value = const ShalatLoading();
    final now = DateTime.now();
    final targetBulan = bulan ?? now.month;
    final targetTahun = tahun ?? now.year;

    try {
      final isOnline = await _checkConnectivity();
      JadwalShalat jadwal;
      bool isOffline = false;

      if (isOnline) {
        final model = await _remote.getJadwalShalat(
          provinsi: provinsi,
          kabkota: kabkota,
          bulan: targetBulan,
          tahun: targetTahun,
        );
        await _local.saveJadwal(model);
        jadwal = model.toDomain();
      } else {
        final cached = await _local.getCachedJadwal(
          provinsi: provinsi,
          kabkota: kabkota,
          bulan: targetBulan,
          tahun: targetTahun,
        );
        if (cached == null) {
          value = const ShalatError(
            'Tidak ada koneksi internet dan belum ada data tersimpan.',
          );
          return;
        }
        jadwal = cached.toDomain();
        isOffline = true;
      }

      final notifEnabled = await _local.isNotifEnabled();
      final koordinat = await _local.getKoordinat();
      final today = jadwal.today;
      final nextWaktu = _findNextWaktu(today);
      final countdown = nextWaktu != null
          ? nextWaktu.dateTime.difference(now)
          : Duration.zero;

      value = ShalatLoaded(
        jadwal: jadwal,
        today: today,
        nextWaktu: nextWaktu,
        countdown: countdown,
        notifEnabled: notifEnabled,
        isOffline: isOffline,
        koordinat: koordinat,
      );

      _startCountdown();

      if (notifEnabled && today != null) {
        // Segarkan jadwal tanpa memunculkan dialog izin. Kegagalan sudah
        // diterjemahkan menjadi pesan di dalam AdzanNotifications.
        final result = await _notifications.enable(
          times: today.allWaktu,
          kabkota: kabkota,
        );
        if (result.message != null && value is ShalatLoaded) {
          value = (value as ShalatLoaded).copyWith(
            notifMessage: result.message,
          );
        }
      }
    } on ShalatApiException catch (e) {
      // Fallback ke cache
      final cached = await _local.getCachedJadwal(
        provinsi: provinsi,
        kabkota: kabkota,
        bulan: targetBulan,
        tahun: targetTahun,
      );
      if (cached != null) {
        final jadwal = cached.toDomain();
        final notifEnabled = await _local.isNotifEnabled();
        final today = jadwal.today;
        final nextWaktu = _findNextWaktu(today);
        value = ShalatLoaded(
          jadwal: jadwal,
          today: today,
          nextWaktu: nextWaktu,
          countdown: nextWaktu != null
              ? nextWaktu.dateTime.difference(now)
              : Duration.zero,
          notifEnabled: notifEnabled,
          isOffline: true,
        );
        _startCountdown();
      } else {
        value = ShalatError(e.message);
      }
    } catch (_) {
      value = const ShalatError(
        'Jadwal shalat belum bisa dimuat. Periksa koneksi internet Anda, '
        'atau pilih kota lain.',
      );
    }
  }

  // ── Navigasi bulan ────────────────────────────────────────────────────────

  Future<void> loadBulan(int bulan, int tahun) async {
    final state = value;
    if (state is! ShalatLoaded) return;
    await _loadJadwal(
      provinsi: state.jadwal.provinsi,
      kabkota: state.jadwal.kabkota,
      bulan: bulan,
      tahun: tahun,
    );
  }

  // ── Notifikasi ────────────────────────────────────────────────────────────

  /// Nyalakan/matikan pengingat adzan.
  ///
  /// Tidak pernah melempar: izin ditolak, alarm tidak eksak, dan kegagalan
  /// plugin semuanya berakhir sebagai [ShalatLoaded.notifMessage].
  Future<void> toggleNotification() async {
    final state = value;
    if (state is! ShalatLoaded) return;

    if (!state.notifEnabled) {
      final result = state.today == null
          ? const AdzanResult(
              ok: false,
              message: 'Jadwal hari ini belum tersedia.',
            )
          : await _notifications.enable(
              times: state.today!.allWaktu,
              kabkota: state.jadwal.kabkota,
              askPermission: true,
            );
      if (!result.ok) {
        value = state.copyWith(notifMessage: result.message);
        return;
      }
      await _local.setNotifEnabled(true);
      value = state.copyWith(notifEnabled: true, notifMessage: result.message);
      return;
    }

    await _local.setNotifEnabled(false);
    await _notifications.disable();
    value = state.copyWith(notifEnabled: false, clearNotifMessage: true);
  }

  // ── Countdown timer ───────────────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final state = value;
      if (state is! ShalatLoaded) return;

      final now = DateTime.now();
      final next = _findNextWaktu(state.today);

      if (next == null) {
        value = state.copyWith(clearNextWaktu: true, countdown: Duration.zero);
        _countdownTimer?.cancel();
        return;
      }

      final diff = next.dateTime.difference(now);
      if (diff.isNegative) {
        // Waktu sudah lewat, cari yang berikutnya
        value = state.copyWith(nextWaktu: next, countdown: Duration.zero);
      } else {
        value = state.copyWith(nextWaktu: next, countdown: diff);
      }
    });
  }

  ShalatEntry? _findNextWaktu(WaktuShalat? today) {
    if (today == null) return null;
    final now = DateTime.now();
    // Skip "Terbit" dari countdown
    return today.allWaktu
        .where((e) => e.nama != 'Terbit' && e.dateTime.isAfter(now))
        .firstOrNull;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<List<String>> _getProvinsi() async {
    if (_cachedProvinsi != null) return _cachedProvinsi!;
    _cachedProvinsi = await _remote.getProvinsi();
    return _cachedProvinsi!;
  }

  Future<List<String>> _getKabkota(String provinsi) async {
    if (_cachedKabkota.containsKey(provinsi)) return _cachedKabkota[provinsi]!;
    final list = await _remote.getKabkota(provinsi);
    _cachedKabkota[provinsi] = list;
    return list;
  }

  Future<bool> _checkConnectivity() async {
    final override = _connectivityCheck;
    if (override != null) return override();
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any(
        (r) =>
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.ethernet,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
