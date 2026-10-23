import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../progress/record_result.dart';
import 'reminder_plan.dart';
import 'reminder_scheduler.dart';

/// Pengingat harian murojaah: saklar, jam, izin, dan penjadwalan.
///
/// Penjadwalan ulang selalu dipicu peristiwa nyata — aplikasi dibuka, jam
/// diubah, saklar dinyalakan, atau [onRecorded] menerima [RecordResult] —
/// bukan dengan menebak dari timer.
class MurojaahReminder extends ChangeNotifier {
  MurojaahReminder({
    required ReminderScheduler scheduler,
    DateTime Function()? clock,
  }) : _scheduler = scheduler,
       _clock = clock ?? DateTime.now;

  static const keyEnabled = 'quran_reminder_enabled';
  static const keyHour = 'quran_reminder_hour';
  static const keyMinute = 'quran_reminder_minute';

  /// Id notifikasi per hari ke depan: [baseId] + offset hari.
  static const baseId = 7100;

  final ReminderScheduler _scheduler;
  final DateTime Function() _clock;

  bool _enabled = false;
  int _hour = ReminderPlanner.defaultHour;
  int _minute = ReminderPlanner.defaultMinute;
  ReminderPermission _permission = ReminderPermission.unknown;
  bool _loaded = false;
  bool _activeToday = false;
  int _streak = 0;

  bool get enabled => _enabled;
  int get hour => _hour;
  int get minute => _minute;
  ReminderPermission get permission => _permission;
  bool get isLoaded => _loaded;

  /// Jam dalam format `HH:mm`.
  String get timeLabel =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(keyEnabled) ?? false;
      _hour = prefs.getInt(keyHour) ?? ReminderPlanner.defaultHour;
      _minute = prefs.getInt(keyMinute) ?? ReminderPlanner.defaultMinute;
    } catch (_) {
      // Prefs rusak tidak boleh menjatuhkan aplikasi: pakai default.
    }
    _loaded = true;
    if (_enabled) {
      _permission = await _checkPermission();
      if (_permission != ReminderPermission.granted) _enabled = false;
    }
    notifyListeners();
    await _apply();
  }

  /// Sinkronkan kondisi hari ini (dari log progres), lalu pasang ulang jadwal.
  ///
  /// Dipanggil saat aplikasi dibuka dan setiap kali progres berubah.
  Future<void> sync({required bool activeToday, required int streak}) async {
    _activeToday = activeToday;
    _streak = streak;
    await _apply();
  }

  /// Dipicu hasil pencatatan — bukan tebakan.
  Future<void> onRecorded(RecordResult result, {required bool activeToday}) =>
      sync(activeToday: activeToday, streak: result.newStreak);

  Future<ReminderPermission> _checkPermission() async {
    try {
      return await _scheduler.hasPermission()
          ? ReminderPermission.granted
          : ReminderPermission.denied;
    } catch (_) {
      return ReminderPermission.denied;
    }
  }

  /// Nyalakan/matikan pengingat.
  ///
  /// Saat dinyalakan, izin diminta lebih dulu (penjelasan ramah ditampilkan UI
  /// sebelum dialog sistem). Izin ditolak bukan error: saklar kembali mati dan
  /// [permission] menjadi [ReminderPermission.denied].
  Future<void> setEnabled(bool value) async {
    if (value) {
      _permission = await _checkPermission();
      if (_permission != ReminderPermission.granted) {
        final granted = await _scheduler.requestPermission();
        _permission = granted
            ? ReminderPermission.granted
            : ReminderPermission.denied;
      }
      if (_permission != ReminderPermission.granted) {
        _enabled = false;
        notifyListeners();
        await _save(enabled: false);
        return;
      }
    }

    _enabled = value;
    notifyListeners();
    await _save(enabled: value);
    await _apply();
  }

  Future<void> setTime(int hour, int minute) async {
    _hour = hour;
    _minute = minute;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(keyHour, hour);
      await prefs.setInt(keyMinute, minute);
    } catch (_) {}
    await _apply();
  }

  /// Pulihkan pengaturan pengingat dari cadangan, lalu pasang ulang jadwal.
  ///
  /// Jadwal notifikasi tidak ikut tercadang (dikelola sistem), jadi satu-satunya
  /// cara memulihkannya adalah membangun ulang dari pengaturan — persis yang
  /// dilakukan [_apply] di sini dan di [load] saat aplikasi dibuka.
  Future<void> restoreSettings({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    _enabled = enabled;
    _hour = hour.clamp(0, 23);
    _minute = minute.clamp(0, 59);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyEnabled, _enabled);
      await prefs.setInt(keyHour, _hour);
      await prefs.setInt(keyMinute, _minute);
    } catch (_) {}
    await _apply();
  }

  Future<void> openSystemSettings() async {    try {
      await _scheduler.openSystemSettings();
    } catch (_) {}
  }

  Future<void> _apply() async {
    if (!_enabled) {
      await _safeCancel();
      return;
    }
    // Izin bisa dicabut kapan saja dari pengaturan sistem; periksa ulang
    // setiap kali jadwal dipasang supaya saklar tidak berbohong.
    _permission = await _checkPermission();
    if (_permission != ReminderPermission.granted) {
      _enabled = false;
      notifyListeners();
      await _save(enabled: false);
      await _safeCancel();
      return;
    }

    final plan = ReminderPlanner.plan(
      now: _clock(),
      hour: _hour,
      minute: _minute,
      activeToday: _activeToday,
      streak: _streak,
    );
    await _safeCancel();
    for (var i = 0; i < plan.times.length; i++) {
      await _scheduler.schedule(
        id: baseId + i,
        at: plan.times[i],
        title: plan.title,
        body: plan.bodyAt(i),
      );
    }
  }

  Future<void> _safeCancel() async {
    try {
      await _scheduler.cancel();
    } catch (_) {}
  }

  Future<void> _save({required bool enabled}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyEnabled, enabled);
    } catch (_) {}
  }
}
