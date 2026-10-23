import 'package:geocoding/geocoding.dart';

/// Nama wilayah hasil reverse geocode, dipisah dari tipe paket `geocoding`
/// supaya bisa dipalsukan di test tanpa plugin.
class PlaceNames {
  const PlaceNames({
    this.administrativeArea,
    this.locality,
    this.subAdministrativeArea,
  });

  /// Provinsi (mis. "DKI Jakarta").
  final String? administrativeArea;

  /// Kota/kabupaten (mis. "Jakarta Pusat").
  final String? locality;

  /// Kecamatan; dipakai sebagai cadangan bila [locality] kosong.
  final String? subAdministrativeArea;
}

/// Reverse geocoding + fuzzy match nama wilayah ke daftar dari API.
///
/// Pengambilan koordinat ada di `location_provider.dart`; kelas ini murni
/// pengolahan nama, jadi mudah dites tanpa plugin.
class LocationService {
  /// Reverse geocode koordinat ke nama wilayah. Null bila gagal — pemanggil
  /// menawarkan pilihan kota manual.
  Future<PlaceNames?> reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      return PlaceNames(
        administrativeArea: p.administrativeArea,
        locality: p.locality,
        subAdministrativeArea: p.subAdministrativeArea,
      );
    } catch (_) {
      return null;
    }
  }

  /// Koordinat perkiraan untuk kota yang dipilih manual. Dipakai menghitung
  /// arah kiblat saat perangkat tidak memberi GPS. Null bila tidak ketemu —
  /// pemanggil hanya kehilangan arah kiblat, bukan jadwal shalat.
  ///
  /// Akurasi tingkat kota sudah cukup: galat 50 km hanya menggeser bearing
  /// kiblat < 0,5 derajat.
  Future<({double latitude, double longitude})?> coordinatesForCity(
    String provinsi,
    String kabkota,
  ) async {
    try {
      final results = await locationFromAddress(
        '$kabkota, $provinsi, Indonesia',
      );
      if (results.isEmpty) return null;
      return (
        latitude: results.first.latitude,
        longitude: results.first.longitude,
      );
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
  String? matchKabkota(
    String? locality,
    String? subAdmin,
    List<String> kabkotaList,
  ) {
    final candidates = [
      locality,
      subAdmin,
    ].where((s) => s != null && s.isNotEmpty).cast<String>().toList();

    for (final query in candidates) {
      final q = _normalize(query);

      // Exact match
      for (final k in kabkotaList) {
        if (_normalize(k) == q) return k;
      }

      // Contains match (strip "kab."/"kota." prefix dari API)
      for (final k in kabkotaList) {
        final stripped = _normalize(
          k,
        ).replaceAll('kab.', '').replaceAll('kota', '').trim();
        if (stripped.contains(q) || q.contains(stripped)) return k;
      }
    }
    return null;
  }

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
}
