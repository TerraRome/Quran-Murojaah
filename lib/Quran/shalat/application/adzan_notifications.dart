import 'package:flutter/foundation.dart';

import '../domain/entities/waktu_shalat.dart';
import 'notification_service.dart';

/// Hasil satu percobaan memasang jadwal adzan.
///
/// [ok] false berarti tidak ada jadwal yang terpasang; [message] selalu berisi
/// kalimat siap tampil untuk pengguna (bukan teks exception).
class AdzanResult {
  const AdzanResult({required this.ok, this.message, this.inexact = false});

  const AdzanResult.success() : ok = true, message = null, inexact = false;

  final bool ok;
  final String? message;

  /// Jadwal terpasang, tetapi memakai alarm tidak eksak (bisa terlambat
  /// beberapa menit). Bukan kegagalan, tetap perlu diberitahukan.
  final bool inexact;
}

/// Jembatan tipis ke plugin notifikasi. Implementasi palsu dipakai di test,
/// jadi tidak ada test yang menyentuh plugin atau perangkat.
abstract class AdzanScheduler {
  Future<bool> requestPermission();

  /// Apakah sistem mengizinkan alarm eksak. Android 12+ bisa menolak; iOS
  /// tidak punya konsep ini dan selalu true.
  Future<bool> canScheduleExact();

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required bool exact,
  });

  /// Batalkan notifikasi adzan saja — pengingat murojaah tidak boleh ikut mati.
  Future<void> cancel();
}

/// Aturan pemasangan notifikasi adzan, tanpa plugin dan tanpa widget.
///
/// Dua hal yang dijaga di sini:
/// - perangkat tanpa izin alarm eksak (Android 12+) tetap mendapat jadwal,
///   hanya tidak eksak — bukan crash, bukan exception ke UI;
/// - kegagalan plugin apa pun ditangkap dan diterjemahkan menjadi pesan ramah.
class AdzanNotifications {
  const AdzanNotifications(this._scheduler, {DateTime Function()? clock})
    : _clock = clock;

  static const _skipNames = {'Terbit'};

  final AdzanScheduler _scheduler;
  final DateTime Function()? _clock;

  DateTime _now() => (_clock ?? DateTime.now)();

  /// Pasang ulang seluruh jadwal hari ini.
  ///
  /// [askPermission] true saat pengguna menyalakan saklar; false saat jadwal
  /// disegarkan otomatis (mis. aplikasi dibuka) supaya tidak ada dialog izin
  /// yang muncul tanpa diminta.
  Future<AdzanResult> enable({
    required List<ShalatEntry> times,
    required String kabkota,
    bool askPermission = false,
  }) async {
    await _safeCancel();

    if (askPermission) {
      var granted = false;
      try {
        granted = await _scheduler.requestPermission();
      } catch (_) {
        granted = false;
      }
      if (!granted) {
        return const AdzanResult(
          ok: false,
          message: 'Izin notifikasi belum diberikan, jadi pengingat adzan '
              'belum bisa dipasang.',
        );
      }
    }

    var exact = false;
    try {
      exact = await _scheduler.canScheduleExact();
    } catch (_) {
      exact = false;
    }

    final now = _now();
    var scheduled = 0;
    for (final entry in times) {
      if (_skipNames.contains(entry.nama)) continue;
      if (entry.dateTime.isBefore(now)) continue;
      try {
        await _scheduler.schedule(
          id: _notifId(entry.nama),
          title: 'Waktu ${entry.nama}',
          body: '$kabkota · ${entry.waktu}',
          at: entry.dateTime,
          exact: exact,
        );
        scheduled++;
      } catch (error) {
        debugPrint('Adzan ${entry.nama} gagal dipasang: $error');
        await _safeCancel();
        return const AdzanResult(
          ok: false,
          message: 'Pengingat adzan tidak bisa dipasang di perangkat ini. '
              'Jadwal shalat tetap bisa dibaca seperti biasa.',
        );
      }
    }

    if (scheduled == 0) {
      return const AdzanResult(
        ok: false,
        message: 'Tidak ada waktu shalat tersisa hari ini.',
      );
    }
    if (!exact) {
      return const AdzanResult(
        ok: true,
        inexact: true,
        message: 'Sistem tidak mengizinkan alarm eksak, jadi adzan bisa '
            'berbunyi beberapa menit lebih lambat.',
      );
    }
    return const AdzanResult.success();
  }

  Future<void> disable() => _safeCancel();

  Future<void> _safeCancel() async {
    try {
      await _scheduler.cancel();
    } catch (error) {
      debugPrint('Gagal membatalkan notifikasi adzan: $error');
    }
  }

  /// Id stabil per waktu, di rentang 0–99 (di luar rentang pengingat murojaah).
  static int _notifId(String nama) => nama.hashCode.abs() % 100;
}

/// Implementasi nyata di atas [NotificationService].
class PluginAdzanScheduler implements AdzanScheduler {
  const PluginAdzanScheduler();

  @override
  Future<bool> requestPermission() => NotificationService.requestPermission();

  @override
  Future<bool> canScheduleExact() => NotificationService.canScheduleExact();

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required bool exact,
  }) => NotificationService.scheduleOne(
    id: id,
    title: title,
    body: body,
    at: at,
    exact: exact,
  );

  @override
  Future<void> cancel() => NotificationService.cancelAdzan();
}
