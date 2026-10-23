import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Sebab lokasi tidak bisa dipakai. Setiap nilai punya pesan ramah + aksi di
/// halaman Shalat; tidak ada yang boleh muncul sebagai exception mentah.
enum LocationIssue { serviceOff, denied, deniedForever, timeout, failed }

/// Hasil permintaan lokasi.
sealed class LocationOutcome {
  const LocationOutcome();
}

class LocationFix extends LocationOutcome {
  const LocationFix(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

class LocationUnavailable extends LocationOutcome {
  const LocationUnavailable(this.issue);
  final LocationIssue issue;
}

/// Aksi yang ditawarkan saat lokasi bermasalah.
enum LocationAction { retry, openAppSettings, openLocationSettings, manualOnly }

/// Pesan ramah + aksi untuk satu [LocationIssue]. Murni teks, bisa dites.
class LocationIssueCopy {
  const LocationIssueCopy(this.title, this.body, this.action);
  final String title;
  final String body;
  final LocationAction action;
}

LocationIssueCopy copyForIssue(LocationIssue issue) => switch (issue) {
      LocationIssue.serviceOff => const LocationIssueCopy(
          'Lokasi perangkat mati',
          'Nyalakan GPS atau layanan lokasi supaya jadwal shalat sesuai kota '
              'Anda. Anda juga bisa memilih kota sendiri.',
          LocationAction.openLocationSettings,
        ),
      LocationIssue.denied => const LocationIssueCopy(
          'Izin lokasi belum diberikan',
          'Tanpa izin lokasi, kami tidak bisa menebak kota Anda. Pilih kota '
              'secara manual, atau coba izinkan lagi.',
          LocationAction.retry,
        ),
      LocationIssue.deniedForever => const LocationIssueCopy(
          'Izin lokasi diblokir',
          'Izin lokasi dimatikan permanen untuk aplikasi ini. Buka pengaturan '
              'aplikasi untuk mengizinkannya, atau pilih kota manual.',
          LocationAction.openAppSettings,
        ),
      LocationIssue.timeout => const LocationIssueCopy(
          'Lokasi lama ditemukan',
          'Satelit tidak menjawab dalam 15 detik. Coba lagi di tempat terbuka, '
              'atau pilih kota manual.',
          LocationAction.retry,
        ),
      LocationIssue.failed => const LocationIssueCopy(
          'Lokasi tidak terbaca',
          'Perangkat tidak memberi lokasi saat ini. Pilih kota manual supaya '
              'jadwal shalat tetap tampil.',
          LocationAction.retry,
        ),
    };

/// Sumber lokasi. Antarmuka tipis supaya test memakai penyedia palsu.
abstract class LocationProvider {
  /// Status izin saat ini tanpa memunculkan dialog sistem.
  ///
  /// Dipakai untuk memutuskan perlu-tidaknya menjelaskan alasan lebih dulu.
  Future<bool> hasPermission();

  Future<LocationOutcome> currentLocation();
  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}

/// Implementasi nyata di atas `geolocator`.
///
/// Akurasi `low` sengaja dipilih: manifest hanya meminta ACCESS_COARSE_LOCATION,
/// jadi meminta akurasi tinggi hanya akan menunggu sinyal yang tidak diizinkan.
class GeolocatorLocationProvider implements LocationProvider {
  const GeolocatorLocationProvider();

  static const _timeLimit = Duration(seconds: 15);

  @override
  Future<bool> hasPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<LocationOutcome> currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationUnavailable(LocationIssue.serviceOff);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationUnavailable(LocationIssue.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationUnavailable(LocationIssue.denied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: _timeLimit,
        ),
      );
      return LocationFix(position.latitude, position.longitude);
    } on TimeoutException {
      return const LocationUnavailable(LocationIssue.timeout);
    } catch (_) {
      // Termasuk PermissionUndefinedException, LocationServiceDisabledException,
      // dan kegagalan plugin lain: semuanya menjadi satu pesan ramah.
      return const LocationUnavailable(LocationIssue.failed);
    }
  }

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
