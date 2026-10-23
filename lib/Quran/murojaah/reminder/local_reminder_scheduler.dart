import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_controller.dart';
import 'reminder_plan.dart';
import 'reminder_scheduler.dart';

/// Implementasi [ReminderScheduler] di atas `flutter_local_notifications`.
///
/// Jadwal memakai mode **tidak eksak** (`inexactAllowWhileIdle`), jadi aplikasi
/// tidak perlu izin `SCHEDULE_EXACT_ALARM` — pengingat kebiasaan tidak butuh
/// ketepatan detik.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Kanal khusus pengingat murojaah, terpisah dari kanal adzan.
  static const channel = AndroidNotificationChannel(
    'murojaah_reminder',
    'Pengingat Murojaah',
    description: 'Pengingat harian murojaah dan streak',
  );

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Izin diminta saat pengguna menyalakan pengingat, bukan saat startup.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    final android = await _android?.requestNotificationsPermission();
    if (android != null) return android;
    final ios = await _ios?.requestPermissions(alert: true, sound: true);
    return ios ?? false;
  }

  @override
  Future<bool> hasPermission() async {
    await _ensureInitialized();
    final android = await _android?.areNotificationsEnabled();
    if (android != null) return android;
    final ios = await _ios?.checkPermissions();
    return ios?.isEnabled ?? false;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();
    // `at` adalah DateTime lokal; konversi ke UTC dulu supaya zona waktu
    // perangkat sudah terselesaikan (termasuk DST) tanpa perlu nama zona IANA.
    final when = tz.TZDateTime.from(at.toUtc(), tz.UTC);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel() async {
    await _ensureInitialized();
    // Hanya id milik pengingat murojaah — `cancelAll()` akan ikut menghapus
    // jadwal adzan.
    for (var i = 0; i <= ReminderPlanner.maxDays; i++) {
      await _plugin.cancel(MurojaahReminder.baseId + i);
    }
  }

  @override
  Future<void> openSystemSettings() async {
    await openAppSettings();
  }
}
