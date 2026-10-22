import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/progress/activity_entry.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_controller.dart';
import 'package:quran/Quran/murojaah/progress/progress_service.dart';
import 'package:quran/Quran/murojaah/progress/record_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

ActivityEntry _entry(
  DateTime at, {
  int surah = 1,
  int from = 1,
  int to = 1,
  double? accuracy = 1,
  ActivityType type = ActivityType.murojaah,
}) => ActivityEntry(
  at: at,
  surahNumber: surah,
  fromVerse: from,
  toVerse: to,
  type: type,
  accuracy: type == ActivityType.murojaah ? accuracy : null,
);

Future<MurojaahProgressController> _controller([
  List<ActivityEntry> seed = const [],
]) async {
  final controller = MurojaahProgressController(
    store: MemoryActivityStore(seed),
  );
  await controller.load();
  return controller;
}

void main() {
  final now = DateTime(2026, 10, 22, 20, 30);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RecordResult — XP', () {
    test('5 XP per ayat yang terbaca dengan akurasi cukup', () async {
      final progress = await _controller();
      final result = await progress.record(
        surahNumber: 1,
        fromVerse: 1,
        toVerse: 4,
        accuracy: 1,
        at: now,
      );
      expect(result.xpGained, 20);
      expect(result.newLevel, 1);
      expect(result.leveledUp, isFalse);
    });

    test(
      'akurasi di bawah ambang tidak memberi XP, tapi tetap tercatat',
      () async {
        final progress = await _controller();
        final result = await progress.record(
          surahNumber: 1,
          fromVerse: 1,
          toVerse: 4,
          accuracy: 0.5,
          at: now,
        );
        expect(result.xpGained, 0);
        expect(progress.entries, hasLength(1));
      },
    );

    test('akurasi null tidak memberi XP', () async {
      final progress = await _controller();
      final result = await progress.record(
        surahNumber: 1,
        fromVerse: 1,
        toVerse: 1,
        at: now,
      );
      expect(result.xpGained, 0);
    });

    test('ayat yang sudah memberi XP hari ini tidak memberi XP lagi', () async {
      final progress = await _controller([
        _entry(now.subtract(const Duration(hours: 2)), from: 1, to: 2),
      ]);
      final result = await progress.record(
        surahNumber: 1,
        fromVerse: 1,
        toVerse: 2,
        accuracy: 1,
        at: now,
      );
      expect(result.xpGained, 0);
    });

    test('batas harian tetap berlaku', () async {
      final progress = await _controller([
        _entry(now.subtract(const Duration(hours: 2)), from: 1, to: 30),
      ]);
      final result = await progress.record(
        surahNumber: 2,
        fromVerse: 1,
        toVerse: 5,
        accuracy: 1,
        at: now,
      );
      expect(result.xpGained, 0);
      expect(progress.snapshot(now: now).todayXp, 150);
    });
  });

  group('RecordResult — streak', () {
    test('naik saat hari ini pertama kali jadi aktif', () async {
      final progress = await _controller([
        _entry(now.subtract(const Duration(days: 1)), from: 1, to: 1),
      ]);
      final result = await progress.record(
        surahNumber: 2,
        fromVerse: 1,
        toVerse: 1,
        accuracy: 1,
        at: now,
      );
      expect(result.streakIncreased, isTrue);
      expect(result.newStreak, 2);
    });

    test(
      'sesi kedua di hari yang sama tidak memunculkan "streak naik" lagi',
      () async {
        final progress = await _controller([
          _entry(now.subtract(const Duration(days: 1)), from: 1, to: 1),
        ]);
        final first = await progress.record(
          surahNumber: 2,
          fromVerse: 1,
          toVerse: 1,
          accuracy: 1,
          at: now,
        );
        final second = await progress.record(
          surahNumber: 2,
          fromVerse: 2,
          toVerse: 2,
          accuracy: 1,
          at: now.add(const Duration(minutes: 5)),
        );
        expect(first.streakIncreased, isTrue);
        expect(second.streakIncreased, isFalse);
        expect(second.newStreak, first.newStreak);
      },
    );

    test('log kosong: hari pertama langsung dihitung streak 1', () async {
      final progress = await _controller();
      final result = await progress.record(
        surahNumber: 1,
        fromVerse: 1,
        toVerse: 1,
        accuracy: 1,
        at: now,
      );
      expect(result.streakIncreased, isTrue);
      expect(result.newStreak, 1);
    });

    test('ambang hari aktif mengikuti ProgressService', () async {
      expect(ProgressService.streakMinVersesPerDay, 1);
    });
  });

  group('RecordResult — target harian', () {
    test('tercapai hanya sekali saat target pertama kali terpenuhi', () async {
      final progress = await _controller();
      await progress.setGoal(DailyGoal.ringan); // 5 ayat

      final partial = await progress.record(
        surahNumber: 1,
        fromVerse: 1,
        toVerse: 3,
        accuracy: 1,
        at: now,
      );
      final crossing = await progress.record(
        surahNumber: 1,
        fromVerse: 4,
        toVerse: 5,
        accuracy: 1,
        at: now.add(const Duration(minutes: 2)),
      );
      final after = await progress.record(
        surahNumber: 1,
        fromVerse: 6,
        toVerse: 7,
        accuracy: 1,
        at: now.add(const Duration(minutes: 4)),
      );

      expect(partial.goalJustReached, isFalse);
      expect(crossing.goalJustReached, isTrue);
      expect(after.goalJustReached, isFalse);
    });

    test(
      'target sudah tercapai sebelum record: bukan "baru tercapai"',
      () async {
        final progress = await _controller();
        await progress.setGoal(DailyGoal.ringan);
        await progress.record(
          surahNumber: 1,
          fromVerse: 1,
          toVerse: 5,
          accuracy: 1,
          at: now,
        );
        final result = await progress.record(
          surahNumber: 1,
          fromVerse: 6,
          toVerse: 7,
          accuracy: 1,
          at: now.add(const Duration(minutes: 1)),
        );
        expect(result.goalJustReached, isFalse);
      },
    );

    test('mengubah target tidak memicu "target tercapai"', () async {
      final progress = await _controller([
        _entry(now.subtract(const Duration(hours: 1)), from: 1, to: 10),
      ]);
      await progress.setGoal(DailyGoal.ringan);
      final result = await progress.record(
        surahNumber: 2,
        fromVerse: 1,
        toVerse: 1,
        accuracy: 1,
        at: now,
      );
      // 10 ayat sudah melewati target 5 sebelum entri ini.
      expect(result.goalJustReached, isFalse);
    });
  });

  group('RecordResult — level', () {
    test('level naik saat XP melewati batas 200', () async {
      final progress = await _controller([
        _entry(
          now.subtract(const Duration(days: 2)),
          surah: 1,
          from: 1,
          to: 30,
        ),
        _entry(now.subtract(const Duration(days: 1)), surah: 2, from: 1, to: 9),
      ]);
      expect(progress.snapshot(now: now).totalXp, 195);
      expect(progress.snapshot(now: now).level, 1);

      final result = await progress.record(
        surahNumber: 3,
        fromVerse: 1,
        toVerse: 1,
        accuracy: 1,
        at: now,
      );

      expect(result.xpGained, 5);
      expect(result.leveledUp, isTrue);
      expect(result.newLevel, 2);
    });

    test('tanpa lonjakan XP, level tetap', () async {
      final progress = await _controller();
      final result = await progress.record(
        surahNumber: 1,
        fromVerse: 1,
        toVerse: 2,
        accuracy: 1,
        at: now,
      );
      expect(result.leveledUp, isFalse);
      expect(result.newLevel, 1);
    });
  });

  group('RecordResult — kasus tepi', () {
    test('rentang tidak valid: tidak ada yang berubah', () async {
      final progress = await _controller();
      final result = await progress.record(
        surahNumber: 1,
        fromVerse: 5,
        toVerse: 2,
        accuracy: 1,
        at: now,
      );
      expect(result.xpGained, 0);
      expect(result.streakIncreased, isFalse);
      expect(progress.entries, isEmpty);
    });

    test('satu nilai waktu dipakai sebelum dan sesudah', () async {
      final progress = await _controller();
      final late = DateTime(2026, 10, 22, 23, 59, 59);
      final result = await progress.record(
        surahNumber: 1,
        fromVerse: 1,
        toVerse: 1,
        accuracy: 1,
        at: late,
      );
      expect(result.streakIncreased, isTrue);
      expect(progress.snapshot(now: late).todayVerses, 1);
    });

    test('penggabungan hasil: XP dijumlah, penanda menang', () {
      const a = RecordResult(
        xpGained: 10,
        streakIncreased: true,
        goalJustReached: false,
        newStreak: 3,
        newLevel: 1,
      );
      const b = RecordResult(
        xpGained: 5,
        streakIncreased: false,
        goalJustReached: true,
        newStreak: 3,
        newLevel: 2,
        leveledUp: true,
      );
      final sum = a + b;
      expect(sum.xpGained, 15);
      expect(sum.streakIncreased, isTrue);
      expect(sum.goalJustReached, isTrue);
      expect(sum.newStreak, 3);
      expect(sum.newLevel, 2);
      expect(sum.leveledUp, isTrue);
    });

    test('RecordResult.none tidak mengubah apa pun saat digabung', () {
      const a = RecordResult(xpGained: 10, newStreak: 2, newLevel: 1);
      expect(a + RecordResult.none, isA<RecordResult>());
      expect((a + RecordResult.none).xpGained, 10);
      expect((a + RecordResult.none).newStreak, 2);
    });
  });
}
