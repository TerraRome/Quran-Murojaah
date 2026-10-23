import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/reminder/reminder_plan.dart';

void main() {
  final now = DateTime(2026, 10, 23, 9);

  ReminderPlan plan({bool activeToday = false, int streak = 0}) =>
      ReminderPlanner.plan(
        now: now,
        hour: ReminderPlanner.defaultHour,
        minute: ReminderPlanner.defaultMinute,
        activeToday: activeToday,
        streak: streak,
      );

  test('jadwal pada jam pilihan, mulai hari ini', () {
    final result = plan();

    expect(result.times.first, DateTime(2026, 10, 23, 20));
    expect(result.times.length, ReminderPlanner.maxDays);
  });

  test('hari aktif menggeser jadwal ke besok', () {
    final result = plan(activeToday: true, streak: 4);

    expect(result.times.first, DateTime(2026, 10, 24, 20));
    expect(result.times.any((t) => t.day == 23), isFalse);
  });

  test('jam hari ini sudah lewat: mulai besok', () {
    final late = ReminderPlanner.plan(
      now: DateTime(2026, 10, 23, 21),
      hour: ReminderPlanner.defaultHour,
      minute: ReminderPlanner.defaultMinute,
      activeToday: false,
      streak: 0,
    );

    expect(late.times.first, DateTime(2026, 10, 24, 20));
  });

  test('batas hari tanpa membuka aplikasi: paling banyak tiga pengingat', () {
    expect(plan().times.length, ReminderPlanner.maxDays);
    expect(plan(activeToday: true).times.length, ReminderPlanner.maxDays);
  });

  test('teks berubah menurut kondisi streak', () {
    expect(plan(streak: 0).body, contains('Belum ada bacaan'));
    expect(plan(streak: 6).body, contains('6 hari'));
    expect(plan(streak: 0).title, isNot(contains('Quran')));
  });

  test('angka streak hanya di notifikasi pertama', () {
    final result = plan(streak: 6);

    expect(result.bodyAt(0), contains('6 hari'));
    for (var i = 1; i < result.times.length; i++) {
      expect(result.bodyAt(i), isNot(contains('6')));
      expect(result.bodyAt(i), isNot(matches(RegExp(r'\d'))));
      expect(result.bodyAt(i), isNotEmpty);
    }
  });

  test('jam pilihan dipakai apa adanya', () {
    final custom = ReminderPlanner.plan(
      now: now,
      hour: 21,
      minute: 30,
      activeToday: false,
      streak: 0,
    );

    expect(custom.times.first, DateTime(2026, 10, 23, 21, 30));
  });
}
