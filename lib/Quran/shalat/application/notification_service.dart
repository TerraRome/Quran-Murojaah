import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service notifikasi via flutter_local_notifications.
///
/// Dua pemilik jadwal berbagi satu plugin:
/// - adzan: id 0–99 ([adzanIdMax]),
/// - pengingat murojaah: id 7100–7102.
///
/// Karena itu tidak ada `cancelAll()` di sini — membatalkan satu fitur tidak
/// boleh menghapus jadwal fitur lain.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Batas atas id notifikasi adzan (inklusif).
  static const adzanIdMax = 99;

  static const _androidChannel = AndroidNotificationChannel(
    'adzan_channel',
    'Pengingat Adzan',
    description: 'Notifikasi waktu shalat harian',
    importance: Importance.high,
  );

  /// Inisialisasi plugin. Panggil sekali saat app start.
  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_androidChannel);

    _initialized = true;
  }

  /// Minta izin notifikasi (iOS + Android 13+).
  ///
  /// Tidak meminta izin alarm eksak: aplikasi tidak mendeklarasikan
  /// `SCHEDULE_EXACT_ALARM`, jadi permintaan itu hanya membuka pengaturan
  /// sistem tanpa hasil. Jadwal tetap jalan dengan alarm tidak eksak.
  static Future<bool> requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    var granted = true;
    if (androidPlugin != null) {
      granted = await androidPlugin.requestNotificationsPermission() ?? false;
    }
    if (iosPlugin != null) {
      granted =
          await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return granted;
  }

  /// Apakah sistem mengizinkan alarm eksak.
  ///
  /// Android 12+ bisa menolak; iOS selalu true. Kegagalan plugin dianggap
  /// "tidak diizinkan" supaya pemanggil jatuh ke alarm tidak eksak.
  static Future<bool> canScheduleExact() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return true;
    try {
      return await androidPlugin.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Pasang satu notifikasi sekali-tampil.
  static Future<void> scheduleOne({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required bool exact,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      // Instant absolut: `at` sudah waktu lokal perangkat, jadi cukup dikirim
      // sebagai UTC. Tidak butuh nama zona IANA.
      tz.TZDateTime.from(at.toUtc(), tz.UTC),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Batalkan notifikasi adzan saja (id 0–[adzanIdMax]).
  static Future<void> cancelAdzan() async {
    for (var id = 0; id <= adzanIdMax; id++) {
      await _plugin.cancel(id);
    }
  }
}
