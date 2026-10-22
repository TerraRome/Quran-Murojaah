import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/progress/activity_entry.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

ActivityEntry _verse(
  DateTime at, {
  required int surah,
  required int from,
  required int to,
  ActivityType type = ActivityType.quranRead,
}) => ActivityEntry(
  at: at,
  surahNumber: surah,
  fromVerse: from,
  toVerse: to,
  type: type,
  accuracy: type == ActivityType.murojaah ? 1 : null,
);

ActivityEntry _doa(DateTime at, String refId) => ActivityEntry(
  at: at,
  surahNumber: ActivityEntry.noSurah,
  fromVerse: 1,
  toVerse: 1,
  type: ActivityType.doa,
  refId: refId,
);

void main() {
  final now = DateTime(2026, 10, 22, 20);

  group('bonus surah tamat', () {
    // Surah 1 = 7 ayat, surah 2 = 45 ayat (dipakai untuk uji batas harian).
    int verseCount(int surah) => switch (surah) {
      1 => 7,
      2 => 45,
      _ => 0,
    };

    ProgressService service(List<ActivityEntry> entries) =>
        ProgressService(entries, verseCount: verseCount);

    test('lengkap dalam satu sesi dapat bonus', () {
      final s = service([
        _verse(now, surah: 1, from: 1, to: 7),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      // 7 ayat × 2 XP + bonus 20.
      expect(s.todayXp, 34);
    });

    test('lengkap lintas sesi di hari yang sama tetap dapat bonus', () {
      final s = service([
        _verse(now, surah: 1, from: 1, to: 4),
        _verse(now.add(const Duration(hours: 2)), surah: 1, from: 5, to: 7),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.todayXp, 34);
    });

    test('kurang satu ayat tidak dapat bonus', () {
      final s = service([
        _verse(now, surah: 1, from: 1, to: 6),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.todayXp, 12);
    });

    test('bonus tunduk pada batas XP harian', () {
      // 45 ayat × 2 = 90 XP, bonus 20 → dibatasi 100.
      final s = service([
        _verse(now, surah: 2, from: 1, to: 45),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.todayXp, ProgressService.dailyXpCap[ActivityType.quranRead]);
    });

    test('bonus hanya sekali per surah per hari', () {
      final s = service([
        _verse(now, surah: 1, from: 1, to: 7),
        _verse(now.add(const Duration(hours: 1)), surah: 1, from: 1, to: 7),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.todayXp, 34);
    });

    test('hari berbeda dapat bonus lagi', () {
      final s = service([
        _verse(now, surah: 1, from: 1, to: 7),
        _verse(now.subtract(const Duration(days: 1)), surah: 1, from: 1, to: 7),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.totalXp, 68);
    });

    test('murojaah tamat surah tidak dapat bonus', () {
      final s = service([
        _verse(now, surah: 1, from: 1, to: 7, type: ActivityType.murojaah),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.todayXp, 35);
    });

    test('tanpa verseCount tidak menebak bonus', () {
      final s = ProgressService([
        _verse(now, surah: 1, from: 1, to: 7),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.todayXp, 14);
    });

    test('verseCount nol tidak memberi bonus', () {
      final s = ProgressService(
        [_verse(now, surah: 99, from: 1, to: 3)],
        verseCount: (_) => 0,
      ).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.todayXp, 6);
    });
  });

  group('streak dari jenis campuran', () {
    test('tafsir dan doa juga mempertahankan streak', () {
      final s = ProgressService([
        _verse(now, surah: 2, from: 1, to: 1, type: ActivityType.murojaah),
        _verse(
          now.subtract(const Duration(days: 1)),
          surah: 2,
          from: 1,
          to: 1,
          type: ActivityType.tafsir,
        ),
        _doa(now.subtract(const Duration(days: 2)), '7'),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.streak, 3);
    });

    test('satu doa sehari cukup untuk hari aktif', () {
      final s = ProgressService([
        _doa(now, '7'),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.activeToday, isTrue);
      expect(s.streak, 1);
    });
  });

  group('cincin target hanya murojaah dan bacaan Quran', () {
    final entries = [
      _verse(now, surah: 2, from: 1, to: 3, type: ActivityType.tafsir),
      _doa(now, '7'),
      _doa(now, '8'),
    ];

    test('tafsir dan doa tidak menambah ayat cincin', () {
      final s = ProgressService(
        entries,
      ).snapshot(now: now, goal: DailyGoal.ringan);
      expect(s.todayVerses, 0);
      expect(s.goalReached, isFalse);
    });

    test('tafsir dan doa tetap membuat hari aktif', () {
      final s = ProgressService(
        entries,
      ).snapshot(now: now, goal: DailyGoal.ringan);
      expect(s.activeToday, isTrue);
    });

    test('ringkasan per jenis menghitung ayat dan jumlah doa', () {
      final s = ProgressService(
        entries,
      ).snapshot(now: now, goal: DailyGoal.ringan);
      expect(s.activityOf(ActivityType.tafsir).count, 3);
      expect(s.activityOf(ActivityType.doa).count, 2);
      expect(s.activityOf(ActivityType.quranRead).count, 0);
      expect(s.activityOf(ActivityType.quranRead).done, isFalse);
      expect(s.activityOf(ActivityType.doa).done, isTrue);
      expect(s.activities.keys, containsAll(ActivityType.values));
    });

    test('kalender memakai ayat cincin, bukan tafsir', () {
      final days = ProgressService(entries).weeklyDays(now: now);
      expect(days.last.verses, 0);
      expect(days.last.active, isTrue);
    });
  });

  group('XP per jenis', () {
    test('tafsir 5 XP per ayat', () {
      final s = ProgressService([
        _verse(now, surah: 2, from: 1, to: 4, type: ActivityType.tafsir),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.todayXp, 20);
    });

    test('doa 5 XP per doa, dedupe per refId', () {
      final s = ProgressService([
        _doa(now, '7'),
        _doa(now.add(const Duration(minutes: 1)), '7'),
        _doa(now.add(const Duration(minutes: 2)), '8'),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.todayXp, 10);
    });

    test('doa tidak memakai nomor ayat surah', () {
      final e = _doa(now, '7');
      expect(e.surahNumber, ActivityEntry.noSurah);
      expect(e.count, 1);
      expect(ProgressService([e]).versesReadIn(1), isEmpty);
    });

    test('total hari = jumlah semua jenis setelah batas masing-masing', () {
      final s = ProgressService([
        _verse(now, surah: 2, from: 1, to: 60, type: ActivityType.murojaah),
        _verse(now, surah: 3, from: 1, to: 60, type: ActivityType.quranRead),
        _verse(now, surah: 4, from: 1, to: 20, type: ActivityType.tafsir),
        _doa(now, '7'),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.todayXp, 150 + 100 + 50 + 5);
    });
  });

  group('migrasi skema v2 → v3', () {
    test('berkas v2 dengan refId terbaca utuh dan ditulis ulang sebagai v3', () {
      const v2 =
          '{"version":2,"entries":['
          '{"at":"2026-10-20T13:00:00.000Z","surah":0,"from":1,"to":1,'
          '"type":"doa","refId":"12"},'
          '{"at":"2026-10-20T13:05:00.000Z","surah":2,"from":1,"to":3,'
          '"type":"quran_read"}'
          ']}';
      final entries = decodeActivityLog(v2);
      expect(entries.length, 2);
      expect(entries.first.refId, '12');
      expect(entries.first.count, 1);
      expect(entries.last.refId, isNull);
      expect(entries.last.type, ActivityType.quranRead);

      final reencoded = encodeActivityLog(entries);
      expect(reencoded, contains('"version":$activitySchemaVersion'));
      expect(activitySchemaVersion, 3);
      expect(decodeActivityLog(reencoded).first.refId, '12');
    });

    test('refId kosong atau bukan string jadi null', () {
      expect(
        ActivityEntry.fromJson({
          'at': '2026-10-20T13:00:00.000Z',
          'surah': 0,
          'from': 1,
          'to': 1,
          'refId': '',
        })!.refId,
        isNull,
      );
      expect(
        ActivityEntry.fromJson({
          'at': '2026-10-20T13:00:00.000Z',
          'surah': 0,
          'from': 1,
          'to': 1,
          'refId': 5,
        })!.refId,
        isNull,
      );
    });

    test('entri doa lama tanpa refId tidak dianggap doa yang sama', () {
      final legacy = ActivityEntry.fromJson({
        'at': '2026-10-20T13:00:00.000Z',
        'surah': 0,
        'from': 1,
        'to': 1,
        'type': 'doa',
      })!;
      expect(legacy.refId, isNull);
      expect(legacy.count, 1);
    });
  });

  group('store: dedupe bertahan setelah muat ulang', () {
    test('prefs menyimpan refId doa', () async {
      SharedPreferences.setMockInitialValues({});
      const store = PrefsActivityStore();
      await store.append(_doa(now, '42'));
      final loaded = await store.load();
      expect(loaded.single.refId, '42');
    });
  });

  group('murottal tidak tercatat', () {
    test('folder murottal tidak menyentuh log aktivitas', () {
      final root = Directory('lib/Quran/murottal');
      expect(root.existsSync(), isTrue, reason: 'jalankan dari root repo');
      final hits = [
        for (final file in root.listSync(recursive: true).whereType<File>())
          if (file.path.endsWith('.dart'))
            for (final line in file.readAsLinesSync())
              if (line.contains('MurojaahProgressController') ||
                  line.contains('ReadingLogRecorder') ||
                  line.contains('ActivityEntry('))
                '${file.path}: $line',
      ];
      expect(hits, isEmpty, reason: hits.join('\n'));
    });
  });
}
