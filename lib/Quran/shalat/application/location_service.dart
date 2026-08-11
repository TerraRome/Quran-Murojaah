import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Hasil deteksi lokasi GPS.
class LocationResult {
  const LocationResult({
    required this.provinsi,
    required this.kabkota,
    required this.isExactMatch,
  });

  final String provinsi;
  final String kabkota;

  /// True jika hasil match persis dari API, false jika perlu konfirmasi manual.
  final bool isExactMatch;
}

/// Service untuk GPS + reverse geocoding + fuzzy match ke list API.
class LocationService {
  /// Minta izin + ambil posisi GPS saat ini.
  /// Throws [LocationException] jika gagal.
  Future<Position> getCurrentPosition() async {
    // Cek apakah GPS aktif
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        'GPS tidak aktif. Aktifkan lokasi di pengaturan perangkat.',
        LocationExceptionType.serviceDisabled,
      );
    }

    // Cek dan minta izin
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException(
          'Izin lokasi ditolak.',
          LocationExceptionType.permissionDenied,
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Izin lokasi ditolak permanen. Aktifkan di pengaturan aplikasi.',
        LocationExceptionType.permissionDeniedForever,
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  /// Reverse geocode koordinat ke alamat.
  Future<Placemark?> reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      return placemarks.isNotEmpty ? placemarks.first : null;
    } catch (_) {
      return null;
    }
  }

  /// Fuzzy match nama administratif ke list provinsi dari API.
  /// Kembalikan null jika tidak ada match yang cukup dekat.
  String? matchProvinsi(String? adminArea, List<String> provinsiList) {
    if (adminArea == null || adminArea.isEmpty) return null;
    final query = _normalize(adminArea);

    // Exact match dulu
    for (final p in provinsiList) {
      if (_normalize(p) == query) return p;
    }

    // Contains match
    for (final p in provinsiList) {
      final norm = _normalize(p);
      if (norm.contains(query) || query.contains(norm)) return p;
    }

    // Token match (e.g. "Jawa Barat" vs "West Java")
    final queryTokens = query.split(' ');
    String? bestMatch;
    int bestScore = 0;
    for (final p in provinsiList) {
      final pTokens = _normalize(p).split(' ');
      int score = 0;
      for (final t in queryTokens) {
        if (pTokens.any((pt) => pt.contains(t) || t.contains(pt))) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestMatch = p;
      }
    }
    return bestScore > 0 ? bestMatch : null;
  }

  /// Fuzzy match nama kota ke list kabkota dari API.
  String? matchKabkota(String? locality, String? subAdmin, List<String> kabkotaList) {
    final candidates = [locality, subAdmin]
        .where((s) => s != null && s.isNotEmpty)
        .cast<String>()
        .toList();

    for (final query in candidates) {
      final q = _normalize(query);

      // Exact match
      for (final k in kabkotaList) {
        if (_normalize(k) == q) return k;
      }

      // Contains match (strip "kab."/"kota." prefix dari API)
      for (final k in kabkotaList) {
        final stripped = _normalize(k)
            .replaceAll('kab.', '')
            .replaceAll('kota', '')
            .trim();
        if (stripped.contains(q) || q.contains(stripped)) return k;
      }
    }
    return null;
  }

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .trim();
}

/// Exception untuk error lokasi.
class LocationException implements Exception {
  const LocationException(this.message, this.type);
  final String message;
  final LocationExceptionType type;

  @override
  String toString() => 'LocationException: $message';
}

enum LocationExceptionType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  geocodingFailed,
}
