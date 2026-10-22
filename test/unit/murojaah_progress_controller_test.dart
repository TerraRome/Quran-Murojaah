import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/progress/activity_entry.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_controller.dart';
import 'package:quran/Quran/murojaah/progress/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 10, 22, 20);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('load membaca log yang sudah ada', () async {
    final store = MemoryActivityStore([
      ActivityEntry(at: now, surahNumber: 1, fromVerse: 1, toVerse: 7),
    ]);
    final c = MurojaahProgressController(store: store);
    expect(c.isLoaded, isFalse);
    await c.load();
    expect(c.isLoaded, isTrue);
    expect(c.snapshot(now: now).todayVerses, 7);
  });

  test('record menambah entri dan memberi tahu pendengar', () async {
    final c = MurojaahProgressController(store: MemoryActivityStore());
    await c.load();
    var notified = 0;
    c.addListener(() => notified++);

    await c.record(surahNumber: 2, fromVerse: 1, toVerse: 5, at: now);

    expect(notified, 1);
    expect(c.entries.length, 1);
    expect(c.entries.single.type, ActivityType.murojaah);
    expect(c.snapshot(now: now).totalXp, 0); // tanpa akurasi = tanpa XP
    expect(c.snapshot(now: now).todayVerses, 5);
  });

  test('record menyimpan jenis aktivitas dan akurasi', () async {
    final c = MurojaahProgressController(store: MemoryActivityStore());
    await c.load();
    await c.record(
      surahNumber: 2,
      fromVerse: 1,
      toVerse: 3,
      accuracy: 0.95,
      at: now,
    );
    expect(c.entries.single.accuracy, 0.95);
    expect(c.snapshot(now: now).totalXp, 15);
    expect(c.snapshot(now: now).todayXp, 15);
  });

  test('record jenis lain tidak butuh akurasi', () async {
    final c = MurojaahProgressController(store: MemoryActivityStore());
    await c.load();
    await c.record(
      surahNumber: 2,
      fromVerse: 1,
      toVerse: 4,
      type: ActivityType.quranRead,
      at: now,
    );
    expect(c.entries.single.accuracy, isNull);
    // Bacaan Quran 2 XP/ayat.
    expect(c.snapshot(now: now).totalXp, 8);
  });

  test('record menolak rentang terbalik tanpa melempar', () async {
    final c = MurojaahProgressController(store: MemoryActivityStore());
    await c.load();
    await c.record(surahNumber: 1, fromVerse: 5, toVerse: 2, at: now);
    await c.record(surahNumber: 1, fromVerse: 0, toVerse: 2, at: now);
    expect(c.entries, isEmpty);
  });

  test('target harian tersimpan dan dipulihkan', () async {
    final a = MurojaahProgressController(store: MemoryActivityStore());
    await a.load();
    await a.setGoal(DailyGoal.serius);

    final b = MurojaahProgressController(store: MemoryActivityStore());
    await b.load();
    expect(b.goal, DailyGoal.serius);
  });

  test('target sama tidak memicu notifikasi', () async {
    final c = MurojaahProgressController(store: MemoryActivityStore());
    await c.load();
    var notified = 0;
    c.addListener(() => notified++);
    await c.setGoal(c.goal);
    expect(notified, 0);
  });

  test('dispose menghentikan notifikasi', () async {
    final c = MurojaahProgressController(store: MemoryActivityStore());
    await c.load();
    var notified = 0;
    c.addListener(() => notified++);
    c.dispose();
    await c.record(surahNumber: 1, fromVerse: 1, toVerse: 1, at: now);
    expect(notified, 0);
  });
}
