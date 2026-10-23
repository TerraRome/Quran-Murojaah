import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/datasources/shalat_local_datasource.dart';
import '../data/datasources/shalat_remote_datasource.dart';
import '../domain/entities/jadwal_shalat.dart';
import '../domain/entities/waktu_shalat.dart';
import 'adzan_notifications.dart';
import 'location_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

sealed class ShalatState {
  const ShalatState();
}

class ShalatLoading extends ShalatState {
  const ShalatLoading();
}

class ShalatNeedLocation extends ShalatState {
  const ShalatNeedLocation({this.errorMessage});
  final String? errorMessage;
}

class ShalatLoaded extends ShalatState {
  const ShalatLoaded({
    required this.jadwal,
    required this.today,
    required this.nextWaktu,
    required this.countdown,
    required this.notifEnabled,
    this.isOffline = false,
    this.notifMessage,
  });

  final JadwalShalat jadwal;
  final WaktuShalat? today;

  /// Waktu shalat berikutnya hari ini. Null jika sudah Isya.
  final ShalatEntry? nextWaktu;

  /// Countdown ke waktu shalat berikutnya.
  final Duration countdown;

  final bool notifEnabled;
  final bool isOffline;

  /// Pesan ramah seputar notifikasi (izin ditolak, alarm tidak eksak, gagal
  /// dipasang). Null = tidak ada yang perlu dikatakan.
  final String? notifMessage;

  String get lokasi => '${jadwal.kabkota}, ${jadwal.provinsi}';

  ShalatLoaded copyWith({
    JadwalShalat? jadwal,
    WaktuShalat? today,
    ShalatEntry? nextWaktu,
    bool clearNextWaktu = false,
    Duration? countdown,
    bool? notifEnabled,
    bool? isOffline,
    String? notifMessage,
    bool clearNotifMessage = false,
  }) =>
      ShalatLoaded(
        jadwal: jadwal ?? this.jadwal,
        today: today ?? this.today,
        nextWaktu: clearNextWaktu ? null : nextWaktu ?? this.nextWaktu,
        countdown: countdown ?? this.countdown,
        notifEnabled: notifEnabled ?? this.notifEnabled,
        isOffline: isOffline ?? this.isOffline,
        notifMessage: clearNotifMessage
            ? null
            : notifMessage ?? this.notifMessage,
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
    AdzanNotifications? notifications,
  })  : _remote = remote,
        _local = local,
        _locationService = locationService,
        _notifications =
            notifications ??
            const AdzanNotifications(PluginAdzanScheduler()),
        super(const ShalatLoading());

  final ShalatRemoteDataSource _remote;
  final ShalatLocalDataSource _local;
  final LocationService _locationService;
  final AdzanNotifications _notifications;

  Timer? _countdownTimer;

  /// Cache in-memory untuk list provinsi dan kabkota.
  List<String>? _cachedProvinsi;
  final Map<String, List<String>> _cachedKabkota = {};

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    value = const ShalatLoading();
    final saved = await _local.getSavedLokasi();
    if (saved.provinsi != null && saved.kabkota != null) {
      await _loadJadwal(
        provinsi: saved.provinsi!,
        kabkota: saved.kabkota!,
      );
    } else {
      value = const ShalatNeedLocation();
    }
  }

  // ── GPS detect ───────────────────────────────────────────────────────────

  /// Deteksi lokasi via GPS → reverse geocode → fuzzy match → load jadwal.
  Future<void> detectLocation() async {
    value = const ShalatLoading();
    try {
      // Pastikan punya list provinsi dulu
      final provinsiList = await _getProvinsi();

      final position = await _locationService.getCurrentPosition();
      final placemark = await _locationService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      final matchedProvinsi = _locationService.matchProvinsi(
        placemark?.administrativeArea,
        provinsiList,
      );

      if (matchedProvinsi == null) {
        value = const ShalatNeedLocation(
          errorMessage: 'Tidak dapat mendeteksi provinsi. Pilih lokasi manual.',
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
        value = ShalatNeedLocation(
          errorMessage:
              'Provinsi terdeteksi: $matchedProvinsi. Pilih kabupaten/kota manual.',
        );
        return;
      }

      await _local.saveLokasi(matchedProvinsi, matchedKabkota);
      await _loadJadwal(provinsi: matchedProvinsi, kabkota: matchedKabkota);
    } on LocationException catch (e) {
      value = ShalatNeedLocation(errorMessage: e.message);
    } catch (e) {
      value = ShalatNeedLocation(
        errorMessage: 'Gagal mendeteksi lokasi: $e',
      );
    }
  }

  // ── Manual lokasi ─────────────────────────────────────────────────────────

  Future<List<String>> getProvinsi() => _getProvinsi();

  Future<List<String>> getKabkota(String provinsi) =>
      _getKabkota(provinsi);

  Future<void> setLokasi(String provinsi, String kabkota) async {
    await _local.saveLokasi(provinsi, kabkota);
    await _loadJadwal(provinsi: provinsi, kabkota: kabkota);
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
      final today = jadwal.today;
      final nextWaktu = _findNextWaktu(today);
      final countdown =
          nextWaktu != null ? nextWaktu.dateTime.difference(now) : Duration.zero;

      value = ShalatLoaded(
        jadwal: jadwal,
        today: today,
        nextWaktu: nextWaktu,
        countdown: countdown,
        notifEnabled: notifEnabled,
        isOffline: isOffline,
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
    } catch (e) {
      value = ShalatError('Terjadi kesalahan: $e');
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
      value = state.copyWith(
        notifEnabled: true,
        notifMessage: result.message,
      );
      return;
    }

    await _local.setNotifEnabled(false);
    await _notifications.disable();
    value = state.copyWith(
      notifEnabled: false,
      clearNotifMessage: true,
    );
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
        value = state.copyWith(
          nextWaktu: next,
          countdown: Duration.zero,
        );
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
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);
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
