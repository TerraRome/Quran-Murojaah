import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/shalat/domain/qibla.dart';

void main() {
  group('qiblaBearing', () {
    void expectBearing(String city, double lat, double lng, double expected) {
      expect(qiblaBearing(lat, lng), closeTo(expected, 0.05), reason: '$city');
    }

    test('kota Indonesia', () {
      expectBearing('Jakarta', -6.2088, 106.8456, 295.15);
      expectBearing('Bandung', -6.9175, 107.6191, 295.17);
      expectBearing('Surabaya', -7.2575, 112.7521, 294.03);
      expectBearing('Medan', 3.5952, 98.6722, 292.77);
      expectBearing('Makassar', -5.1477, 119.4327, 292.48);
      expectBearing('Jayapura', -2.5916, 140.6690, 291.33);
    });

    test('di Ka\'bah bearing nol', () {
      expect(qiblaBearing(kaabaLatitude, kaabaLongitude), closeTo(0, 0.001));
    });

    test('selalu 0..<360', () {
      for (final lat in [-89.0, -45.0, 0.0, 45.0, 89.0]) {
        for (final lng in [-179.0, -90.0, 0.0, 90.0, 179.0]) {
          final b = qiblaBearing(lat, lng);
          expect(b, greaterThanOrEqualTo(0));
          expect(b, lessThan(360));
        }
      }
    });
  });

  group('shortestTurn', () {
    test('wrap-around 359 ke 1 = 2 derajat ke kanan', () {
      expect(shortestTurn(359, 1), closeTo(2, 0.001));
    });

    test('wrap-around 1 ke 359 = -2 derajat ke kiri', () {
      expect(shortestTurn(1, 359), closeTo(-2, 0.001));
    });

    test('batas -180..180', () {
      expect(shortestTurn(0, 180), closeTo(180, 0.001));
      expect(shortestTurn(0, 181), closeTo(-179, 0.001));
      expect(shortestTurn(10, 10), 0);
    });
  });

  group('isFacingQibla', () {
    test('toleransi 5 derajat dua arah', () {
      expect(isFacingQibla(290.15, 295.15), isTrue);
      expect(isFacingQibla(300.15, 295.15), isTrue);
      expect(isFacingQibla(289.9, 295.15), isFalse);
      expect(isFacingQibla(300.4, 295.15), isFalse);
    });

    test('menghadap lewat wrap-around', () {
      expect(isFacingQibla(358, 2), isTrue);
      expect(isFacingQibla(340, 2), isFalse);
    });

    test('toleransi bisa diperlebar', () {
      expect(isFacingQibla(280, 295.15, tolerance: 16), isTrue);
      expect(isFacingQibla(280, 295.15), isFalse);
    });
  });

  group('qiblaInstruction', () {
    test('putar ke kanan', () {
      expect(qiblaInstruction(270, 295), 'Putar ke kanan sekitar 25 derajat.');
    });

    test('putar ke kiri', () {
      expect(qiblaInstruction(320, 295), 'Putar ke kiri sekitar 25 derajat.');
    });

    test('sudah menghadap', () {
      expect(qiblaInstruction(295, 295), 'Sudah menghadap kiblat.');
      expect(qiblaInstruction(358, 2), 'Sudah menghadap kiblat.');
    });

    test('menyeberang utara memilih arah terpendek', () {
      expect(qiblaInstruction(350, 10), 'Putar ke kanan sekitar 20 derajat.');
      expect(qiblaInstruction(10, 350), 'Putar ke kiri sekitar 20 derajat.');
    });
  });
}
