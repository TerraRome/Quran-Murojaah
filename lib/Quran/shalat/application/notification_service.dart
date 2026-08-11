import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../domain/entities/waktu_shalat.dart';

/// Service untuk notifikasi adzan via flutter_local_notifications.
///
/// Hanya schedule waktu shalat yang bukan "Terbit" (Terbit bukan waktu shalat).
/// ID notifikasi: hash dari nama waktu (0-99).
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

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

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Create channel on Android
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);

    _initialized = true;
  }

  /// Minta izin notifikasi (iOS + Android 13+).
  static Future<bool> requestPermission() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    bool granted = true;
    if (androidPlugin != null) {
      granted = await androidPlugin.requestNotificationsPermission() ?? false;
      // Request exact alarms on Android 12+
      await androidPlugin.requestExactAlarmsPermission();
    }
    if (iosPlugin != null) {
      granted = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return granted;
  }

  /// Schedule notifikasi adzan untuk semua waktu hari ini.
  /// Melewati "Terbit" — bukan waktu shalat.
  static Future<void> scheduleAdzan(WaktuShalat waktu, String kabkota) async {
    await cancelAll();

    final skipNames = {'Terbit'};
    final now = DateTime.now();

    for (final entry in waktu.allWaktu) {
      if (skipNames.contains(entry.nama)) continue;
      if (entry.dateTime.isBefore(now)) continue;

      final scheduledTz = tz.TZDateTime.from(entry.dateTime, tz.local);
      await _plugin.zonedSchedule(
        _notifId(entry.nama),
        'Waktu ${entry.nama}',
        '$kabkota · ${entry.waktu}',
        scheduledTz,
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  /// Batalkan semua notifikasi adzan.
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static int _notifId(String nama) => nama.hashCode.abs() % 100;
}
