import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/progress/record_result.dart';
import 'package:quran/Quran/murojaah/reminder/reminder_controller.dart';
import 'package:quran/Quran/murojaah/reminder/reminder_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeScheduler implements ReminderScheduler {
  _FakeScheduler({this.granted = true});

  bool granted;
  bool requested = false;
  bool settingsOpened = false;
  int cancels = 0;
  final List<({int id, DateTime at, String title, String body})> scheduled = [];

  @override
  Future<bool> requestPermission() async {
    requested = true;
    return granted;
  }

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    scheduled.add((id: id, at: at, title: title, body: body));
  }

  @override
  Future<void> cancel() async {
    cancels++;
    scheduled.clear();
  }

  @override
  Future<void> openSystemSettings() async {
    settingsOpened = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeScheduler scheduler;
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    scheduler = _FakeScheduler();
    now = DateTime(2026, 10, 23, 9);
  });

  MurojaahReminder reminder() =>
      MurojaahReminder(scheduler: scheduler, clock: () => now);

  test('saklar mati: semua pengingat dibatalkan', () async {
    final r = reminder();
    await r.load();

    await r.setEnabled(false);

    expect(scheduler.scheduled, isEmpty);
    expect(scheduler.cancels, greaterThan(0));
  });

  test('saklar nyala: satu pengingat per hari pada jam pilihan', () async {
    final r = reminder();
    await r.load();

    await r.setEnabled(true);

    expect(r.enabled, isTrue);
    expect(scheduler.scheduled.first.at, DateTime(2026, 10, 23, 20));
    expect(scheduler.scheduled.length, greaterThanOrEqualTo(1));
  });

  test('hanya pengingat pertama yang memuat angka streak', () async {
    final r = reminder();
    await r.load();
    await r.setEnabled(true);
    await r.onRecorded(
      const RecordResult(streakIncreased: true, newStreak: 7),
      activeToday: false,
    );

    expect(scheduler.scheduled.first.body, contains('7 hari'));
    for (final s in scheduler.scheduled.skip(1)) {
      expect(s.body, isNot(contains('7')));
    }
  });

  test('jam pilihan bisa diubah', () async {
    final r = reminder();
    await r.load();
    await r.setEnabled(true);

    await r.setTime(21, 15);

    expect(r.timeLabel, '21:15');
    expect(scheduler.scheduled.first.at, DateTime(2026, 10, 23, 21, 15));
  });

  test('hari aktif menggeser jadwal ke besok', () async {
    final r = reminder();
    await r.load();
    await r.setEnabled(true);

    await r.onRecorded(
      const RecordResult(streakIncreased: true, newStreak: 1),
      activeToday: true,
    );

    expect(scheduler.scheduled.first.at, DateTime(2026, 10, 24, 20));
    expect(scheduler.scheduled.any((s) => s.at.day == 23), isFalse);
  });

  test('izin ditolak: saklar tidak menyala, bukan error', () async {
    scheduler.granted = false;
    final r = reminder();
    await r.load();

    await r.setEnabled(true);

    expect(r.enabled, isFalse);
    expect(scheduler.requested, isTrue);
    expect(r.permission, ReminderPermission.denied);
    expect(scheduler.scheduled, isEmpty);
  });

  test('jalan ke pengaturan sistem tersedia saat izin ditolak', () async {
    scheduler.granted = false;
    final r = reminder();
    await r.load();
    await r.setEnabled(true);

    await r.openSystemSettings();

    expect(scheduler.settingsOpened, isTrue);
  });

  test(
    'batas hari tanpa membuka: pengingat berhenti setelah tiga hari',
    () async {
      final r = reminder();
      await r.load();
      await r.setEnabled(true);

      expect(scheduler.scheduled.length, 3);
      expect(scheduler.scheduled.last.at, DateTime(2026, 10, 25, 20));
    },
  );

  test('pengaturan dari cadangan memulihkan jadwal tanpa membuka ulang', () async {
    final r = reminder();
    await r.load();
    expect(scheduler.scheduled, isEmpty);

    await r.restoreSettings(enabled: true, hour: 4, minute: 45);

    expect(r.enabled, isTrue);
    expect(r.timeLabel, '04:45');
    // 04:45 sudah lewat pada jam palsu 09:00 → jadwal mulai besok.
    expect(scheduler.scheduled.first.at, DateTime(2026, 10, 24, 4, 45));
  });

  test('pengingat yang tersimpan dimuat ulang', () async {    SharedPreferences.setMockInitialValues({
      MurojaahReminder.keyEnabled: true,
      MurojaahReminder.keyHour: 21,
      MurojaahReminder.keyMinute: 45,
    });
    final r = reminder();

    await r.load();

    expect(r.enabled, isTrue);
    expect(r.timeLabel, '21:45');
    expect(scheduler.scheduled.first.at, DateTime(2026, 10, 23, 21, 45));
  });
}
