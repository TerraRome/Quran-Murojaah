import 'package:flutter_compass/flutter_compass.dart';

/// Satu pembacaan kompas.
class CompassReading {
  const CompassReading({this.heading, this.accuracy});

  /// Arah atas perangkat dalam derajat (0 = utara, searah jarum jam).
  /// Null = perangkat tidak melaporkan heading.
  final double? heading;

  /// Perkiraan galat (derajat). Null = tidak dilaporkan platform.
  final double? accuracy;
}

/// Sumber heading kompas. Dipisah dari plugin supaya bisa dipalsukan di test
/// tanpa menyentuh EventChannel.
///
/// Catatan akurasi: `heading` adalah utara **magnetik**, bukan utara sejati.
/// Deklinasi magnetik diabaikan sepenuhnya — di Indonesia besarnya sekitar
/// 0–2 derajat, jauh di dalam [qiblaTolerance] = 5 derajat, jadi bearing
/// kiblat tetap benar tanpa koreksi. Bila kelak dipakai di lintang tinggi
/// (deklinasi > 5°), koreksi harus ditambahkan di sini, bukan di UI.
abstract class CompassProvider {
  /// Stream pembacaan. Boleh kosong bila perangkat tidak punya sensor.
  Stream<CompassReading> readings();
}

/// Implementasi nyata di atas `flutter_compass`.
class PluginCompassProvider implements CompassProvider {
  const PluginCompassProvider();

  @override
  Stream<CompassReading> readings() {
    final events = FlutterCompass.events;
    if (events == null) return const Stream.empty();
    return events.map(
      (e) => CompassReading(heading: e.heading, accuracy: e.accuracy),
    );
  }
}
