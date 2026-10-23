/// Arah kiblat: matematika murni, tanpa sensor, tanpa jaringan.
///
/// Semua fungsi di sini bebas efek samping supaya bisa dites langsung.
library;

import 'dart:math' as math;

/// Koordinat Ka'bah (Makkah).
const double kaabaLatitude = 21.4225;
const double kaabaLongitude = 39.8262;

/// Toleransi "sudah menghadap kiblat" (derajat).
const double qiblaTolerance = 5;

/// Bearing awal (great-circle) dari [latitude],[longitude] ke Ka'bah.
///
/// Hasil 0..<360, 0 = utara sejati, searah jarum jam.
double qiblaBearing(double latitude, double longitude) {
  final lat1 = _rad(latitude);
  final lat2 = _rad(kaabaLatitude);
  final dLon = _rad(kaabaLongitude - longitude);

  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

  return _normalize(_deg(math.atan2(y, x)));
}

/// Selisih terpendek dari [from] ke [to], hasil -180..180.
///
/// Negatif = putar ke kiri, positif = putar ke kanan.
double shortestTurn(double from, double to) {
  final diff = _normalize(to - from);
  return diff > 180 ? diff - 360 : diff;
}

/// Apakah [heading] sudah menghadap kiblat dalam [tolerance] derajat.
bool isFacingQibla(
  double heading,
  double bearing, {
  double tolerance = qiblaTolerance,
}) => shortestTurn(heading, bearing).abs() <= tolerance;

/// Petunjuk arah dalam bahasa sehari-hari, mis. "Putar ke kanan sekitar 20
/// derajat". Teks, bukan hanya warna atau jarum.
String qiblaInstruction(double heading, double bearing) {
  final turn = shortestTurn(heading, bearing);
  final degrees = turn.abs().round();
  if (degrees <= qiblaTolerance) return 'Sudah menghadap kiblat.';
  final direction = turn > 0 ? 'kanan' : 'kiri';
  return 'Putar ke $direction sekitar $degrees derajat.';
}

double _rad(double degrees) => degrees * math.pi / 180;

double _deg(double radians) => radians * 180 / math.pi;

/// Normalisasi ke 0..<360.
double _normalize(double degrees) {
  final value = degrees % 360;
  return value < 0 ? value + 360 : value;
}
