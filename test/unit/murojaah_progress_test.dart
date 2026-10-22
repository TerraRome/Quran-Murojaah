import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/progress/activity_entry.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_service.dart';
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

void main() {
  final now = DateTime(2026, 10, 22, 20, 30);

  group('ActivityEntry', () {
    test('xp per ayat 5, tapi nol bila akurasi di bawah 90%', () {
      expect(_entry(now, from: 1, to: 3).xp, 15);
      expect(_entry(now, from: 1, to: 3, accuracy: 0.9).xp, 15);
      expect(_entry(now, from: 1, to: 3, accuracy: 0.89).xp, 0);
      expect(_entry(now, from: 1, to: 3, accuracy: null).xp, 0);
    });

    test('jenis non-murojaah tidak butuh akurasi', () {
      final e = _entry(now, from: 1, to: 2, type: ActivityType.quranRead);
      expect(e.accuracy, isNull);
      expect(e.awardsXp, isTrue);
      // Bacaan Quran 2 XP/ayat = 10 XP per 5 ayat.
      expect(e.xp, 4);
      expect(e.xpPerVerseForType, 2);
    });

    test('json bolak-balik utuh termasuk field baru', () {
      final e = ActivityEntry(
        at: DateTime(2026, 10, 22, 5, 15),
        surahNumber: 2,
        fromVerse: 4,
        toVerse: 9,
        type: ActivityType.tafsir,
        accuracy: 0.95,
        synced: true,
      );
      final back = ActivityEntry.fromJson(e.toJson())!;
      expect(back.id, e.id);
      expect(back.at.toUtc(), e.at.toUtc());
      expect(back.surahNumber, 2);
      expect(back.type, ActivityType.tafsir);
      expect(back.accuracy, 0.95);
      expect(back.synced, isTrue);
    });

    test('id unik per entri baru', () {
      final a = _entry(now);
      final b = _entry(now);
      expect(a.id, isNot(b.id));
      expect(a.id.length, 32);
    });

    test('json rusak ditolak, bukan bikin crash', () {
      expect(ActivityEntry.fromJson(null), isNull);
      expect(ActivityEntry.fromJson('bukan map'), isNull);
      expect(
        ActivityEntry.fromJson({'at': 'x', 'surah': 1, 'from': 1, 'to': 2}),
        isNull,
      );
      expect(
        ActivityEntry.fromJson({
          'at': '2026-10-22T00:00:00.000Z',
          'surah': 1,
          'from': 5,
          'to': 2,
        }),
        isNull,
      );
      expect(
        ActivityEntry.fromJson({
          'at': '2026-10-22T00:00:00.000Z',
          'surah': 1,
          'from': 1,
          'to': 2,
          'accuracy': 1.5,
        }),
        isNull,
      );
    });

    test('jenis tak dikenal jatuh ke murojaah', () {
      expect(ActivityType.fromWire('entah'), ActivityType.murojaah);
      expect(ActivityType.fromWire(null), ActivityType.murojaah);
      expect(ActivityType.fromWire('tafsir'), ActivityType.tafsir);
    });
  });

  group('migrasi format lama', () {
    test('array polos tanpa id/type/accuracy tetap terbaca', () {
      const old =
          '[{"at":"2026-10-20T13:00:00.000Z","surah":2,"from":1,"to":7}]';
      final entries = decodeActivityLog(old);
      expect(entries.length, 1);
      expect(entries.single.type, ActivityType.murojaah);
      expect(entries.single.accuracy, isNull);
      expect(entries.single.synced, isFalse);
      expect(entries.single.id, isNotEmpty);
      expect(entries.single.verses, 7);
    });

    test('id entri lama stabil di setiap pemuatan', () {
      const old =
          '[{"at":"2026-10-20T13:00:00.000Z","surah":2,"from":1,"to":7}]';
      expect(
        decodeActivityLog(old).single.id,
        decodeActivityLog(old).single.id,
      );
    });

    test('id entri lama beda bila isinya beda', () {
      const a = '[{"at":"2026-10-20T13:00:00.000Z","surah":2,"from":1,"to":7}]';
      const b = '[{"at":"2026-10-20T13:00:00.000Z","surah":2,"from":1,"to":8}]';
      expect(
        decodeActivityLog(a).single.id,
        isNot(decodeActivityLog(b).single.id),
      );
    });

    test('berkas berversi dibaca dari kunci entries', () {
      final raw = encodeActivityLog([_entry(now, from: 1, to: 3)]);
      expect(raw, contains('"version":$activitySchemaVersion'));
      expect(decodeActivityLog(raw).single.verses, 3);
    });

    test('baris rusak dilewati, sisanya tetap terbaca', () {
      const raw =
          '[{"at":"rusak"},'
          '{"at":"2026-10-20T13:00:00.000Z","surah":2,"from":1,"to":7}]';
      expect(decodeActivityLog(raw).length, 1);
    });

    test('bentuk tak dikenal jadi log kosong', () {
      expect(decodeActivityLog('{"version":2}'), isEmpty);
      expect(decodeActivityLog('"teks"'), isEmpty);
    });

    test('entri lama masih memberi XP bila akurasinya diisi', () {
      final e = ActivityEntry.fromJson({
        'at': '2026-10-20T13:00:00.000Z',
        'surah': 2,
        'from': 1,
        'to': 3,
        'accuracy': 0.95,
      })!;
      expect(e.xp, 15);
    });
  });

  group('tanggal — hari lokal', () {
    test('23:59 dan 00:01 lokal jatuh di hari berbeda', () {
      final late = _entry(DateTime(2026, 10, 22, 23, 59));
      final early = _entry(DateTime(2026, 10, 23, 0, 1));
      expect(late.day, DateTime(2026, 10, 22));
      expect(early.day, DateTime(2026, 10, 23));
      expect(late.day, isNot(early.day));
    });

    test('entri tersimpan UTC kembali ke hari lokal yang sama', () {
      final local = DateTime(2026, 10, 22, 23, 59);
      final back = ActivityEntry.fromJson(_entry(local).toJson())!;
      expect(back.day, DateTime(2026, 10, 22));
    });

    test('entri UTC yang jatuh di hari berbeda tetap dihitung lokal', () {
      // 20:00 UTC = 03:00 WIB esok hari; yang dipakai adalah hari lokal.
      final utc = DateTime.utc(2026, 10, 22, 20);
      final expected = DateTime.utc(2026, 10, 22, 20).toLocal();
      expect(
        _entry(utc).day,
        DateTime(expected.year, expected.month, expected.day),
      );
    });

    test('jam perangkat dimundurkan tidak memunculkan streak palsu', () {
      // Entri "besok" (jam dulu sempat maju) tidak boleh memperpanjang streak.
      final s = ProgressService([
        _entry(now.add(const Duration(days: 1)), from: 1, to: 1),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.streak, 0);
      expect(s.todayVerses, 0);
    });
  });

  group('ProgressService — target harian', () {
    test('tanpa log: nol semua, streak 0', () {
      final s = const ProgressService(
        [],
      ).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.todayVerses, 0);
      expect(s.streak, 0);
      expect(s.totalXp, 0);
      expect(s.todayXp, 0);
      expect(s.level, 1);
      expect(s.goalReached, isFalse);
      expect(s.activeToday, isFalse);
    });

    test('hanya menghitung ayat hari ini untuk cincin', () {
      final service = ProgressService([
        _entry(now.subtract(const Duration(days: 1)), from: 1, to: 15),
        _entry(now, from: 1, to: 4),
      ]);
      final s = service.snapshot(now: now, goal: DailyGoal.ringan);
      expect(s.todayVerses, 4);
      expect(s.goalReached, isFalse);
      expect(s.remaining, 1);
      expect(s.goalFraction, closeTo(0.8, 1e-9));
    });

    test('target tercapai dan sisa tidak negatif', () {
      final s = ProgressService([
        _entry(now, from: 1, to: 12),
      ]).snapshot(now: now, goal: DailyGoal.ringan);
      expect(s.goalReached, isTrue);
      expect(s.remaining, 0);
      expect(s.goalFraction, 1.0);
    });

    test('target default Sedang untuk nilai tak dikenal', () {
      expect(DailyGoal.fromVerses(null), DailyGoal.sedang);
      expect(DailyGoal.fromVerses(999), DailyGoal.sedang);
      expect(DailyGoal.fromVerses(5), DailyGoal.ringan);
      expect(DailyGoal.fromVerses(30), DailyGoal.serius);
    });
  });

  group('ProgressService — streak', () {
    test('hari ini saja = 1', () {
      final s = ProgressService([
        _entry(now, from: 1, to: 1),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.streak, 1);
    });

    test('tiga hari berurutan = 3', () {
      final s = ProgressService([
        _entry(now, from: 1, to: 1),
        _entry(now.subtract(const Duration(days: 1)), from: 1, to: 1),
        _entry(now.subtract(const Duration(days: 2)), from: 1, to: 1),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.streak, 3);
    });

    test('hari ini kosong tapi kemarin ada: streak tetap hidup', () {
      final s = ProgressService([
        _entry(now.subtract(const Duration(days: 1)), from: 1, to: 1),
        _entry(now.subtract(const Duration(days: 2)), from: 1, to: 1),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.streak, 2);
      expect(s.activeToday, isFalse);
    });

    test('satu hari libur dalam seminggu tidak memutus streak', () {
      // 22 aktif, 21 libur, 20 & 19 aktif — semuanya minggu yang sama (19–25).
      final s = ProgressService([
        _entry(now, from: 1, to: 1),
        _entry(now.subtract(const Duration(days: 2)), from: 1, to: 1),
        _entry(now.subtract(const Duration(days: 3)), from: 1, to: 1),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.streak, 3);
    });

    test('dua hari libur dalam seminggu memutus streak', () {
      // 21 dan 19 kosong, keduanya minggu 19–25.
      final s = ProgressService([
        _entry(now, from: 1, to: 1),
        _entry(now.subtract(const Duration(days: 2)), from: 1, to: 1),
        _entry(now.subtract(const Duration(days: 4)), from: 1, to: 1),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.streak, 2);
    });

    test('libur minggu lalu tidak memotong minggu ini', () {
      // 22 Okt 2026 = Kamis. Minggu 19–25 libur di 21, minggu 12–18 libur di 18.
      final s = ProgressService([
        _entry(now, from: 1, to: 1), // 22
        _entry(now.subtract(const Duration(days: 2)), from: 1, to: 1), // 20
        _entry(now.subtract(const Duration(days: 3)), from: 1, to: 1), // 19
        _entry(now.subtract(const Duration(days: 5)), from: 1, to: 1), // 17
        _entry(now.subtract(const Duration(days: 6)), from: 1, to: 1), // 16
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.streak, 5);
    });

    test('dua hari bolong berurutan memutus streak', () {
      final s = ProgressService([
        _entry(now.subtract(const Duration(days: 3)), from: 1, to: 1),
        _entry(now.subtract(const Duration(days: 4)), from: 1, to: 1),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.streak, 0);
    });

    test('beberapa entri di hari yang sama dihitung satu hari', () {
      final s = ProgressService([
        _entry(now, from: 1, to: 2),
        _entry(now, from: 3, to: 4),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.streak, 1);
      expect(s.todayVerses, 4);
    });

    test('mengubah target di tengah hari tidak mengubah riwayat streak', () {
      final service = ProgressService([
        _entry(now, from: 1, to: 2),
        _entry(now.subtract(const Duration(days: 1)), from: 1, to: 1),
        _entry(now.subtract(const Duration(days: 2)), from: 1, to: 1),
      ]);
      final streaks = [
        for (final goal in DailyGoal.values)
          service.snapshot(now: now, goal: goal).streak,
      ];
      expect(streaks, everyElement(3));
      // Yang berubah hanya cincin target, bukan streak.
      expect(
        service.snapshot(now: now, goal: DailyGoal.ringan).goalReached,
        isFalse,
      );
      expect(
        service.snapshot(now: now, goal: DailyGoal.serius).goalFraction,
        lessThan(0.2),
      );
    });

    test('ambang hari aktif = 1 ayat, tercatat sebagai konstanta', () {
      expect(ProgressService.streakMinVersesPerDay, 1);
    });

    test('streak tidak bergantung pada akurasi maupun target', () {
      final s = ProgressService([
        _entry(now, from: 1, to: 1, accuracy: 0.4),
      ]).snapshot(now: now, goal: DailyGoal.serius);
      expect(s.streak, 1);
      expect(s.goalReached, isFalse);
      expect(s.todayXp, 0);
    });
  });

  group('ProgressService — XP', () {
    test('xp total menjumlah semua entri', () {
      final s = ProgressService([
        _entry(now, from: 1, to: 2),
        _entry(now.subtract(const Duration(days: 1)), from: 1, to: 3),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.totalXp, 25);
      expect(s.level, 1);
      expect(s.xpIntoLevel, 25);
      expect(s.levelFraction, closeTo(0.125, 1e-9));
    });

    test('level naik tiap 200 xp', () {
      // Batas harian 150 XP, jadi dua hari dibutuhkan untuk melewati 200.
      final s = ProgressService([
        _entry(now, from: 1, to: 40),
        _entry(now.subtract(const Duration(days: 1)), from: 1, to: 40),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.totalXp, 300);
      expect(s.level, 2);
      expect(s.xpIntoLevel, 100);
    });

    test('akurasi di bawah 90% tidak memberi XP, streak tetap', () {
      final s = ProgressService([
        _entry(now, from: 1, to: 4, accuracy: 0.85),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.totalXp, 0);
      expect(s.todayXp, 0);
      expect(s.todayVerses, 4);
      expect(s.streak, 1);
    });

    test('ayat sama di hari sama tidak memberi XP dua kali', () {
      final s = ProgressService([
        _entry(now, from: 1, to: 3),
        _entry(now.add(const Duration(minutes: 5)), from: 1, to: 3),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.todayXp, 15);
    });

    test('ayat yang tumpang tindih hanya dihitung sekali per ayat', () {
      final s = ProgressService([
        _entry(now, from: 1, to: 3),
        _entry(now.add(const Duration(minutes: 5)), from: 2, to: 5),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.todayXp, 25); // ayat 1–5
    });

    test('ayat sama di hari berbeda tetap memberi XP', () {
      final s = ProgressService([
        _entry(now, from: 1, to: 2),
        _entry(now.subtract(const Duration(days: 1)), from: 1, to: 2),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.totalXp, 20);
    });

    test('surah berbeda dengan nomor ayat sama tetap dihitung', () {
      final s = ProgressService([
        _entry(now, surah: 1, from: 1, to: 1),
        _entry(now, surah: 2, from: 1, to: 1),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.todayXp, 10);
    });

    test('batas XP harian per jenis aktivitas dipatuhi', () {
      final s = ProgressService([
        _entry(now, from: 1, to: 60), // 300 XP mentah, dibatasi 150
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.todayXp, ProgressService.dailyXpCap[ActivityType.murojaah]);
    });

    test('batas berlaku per jenis, bukan gabungan', () {
      final s = ProgressService([
        _entry(now, from: 1, to: 40),
        _entry(now, surah: 2, from: 1, to: 60, type: ActivityType.quranRead),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(
        s.todayXp,
        ProgressService.dailyXpCap[ActivityType.murojaah]! +
            ProgressService.dailyXpCap[ActivityType.quranRead]!,
      );
    });

    test('entri tidak urut tetap dihitung benar', () {
      final s = ProgressService([
        _entry(now.add(const Duration(hours: 2)), from: 1, to: 3),
        _entry(now, from: 1, to: 3),
      ]).snapshot(now: now, goal: DailyGoal.sedang);
      expect(s.todayXp, 15);
    });
  });

  group('ProgressService — kalender 7 hari', () {
    test('selalu 7 hari, paling lama dulu, hari ini terakhir', () {
      final days = ProgressService([
        _entry(now, from: 1, to: 1),
      ]).weeklyDays(now: now);
      expect(days.length, 7);
      expect(days.last.isToday, isTrue);
      expect(days.last.day, DateTime(2026, 10, 22));
      expect(days.first.day, DateTime(2026, 10, 16));
      expect(days.where((d) => d.isToday).length, 1);
    });

    test('hari aktif ditandai, hari kosong tidak', () {
      final days = ProgressService([
        _entry(now, from: 1, to: 3),
        _entry(now.subtract(const Duration(days: 2)), from: 1, to: 1),
      ]).weeklyDays(now: now);
      expect(days.last.active, isTrue);
      expect(days.last.verses, 3);
      expect(days[4].active, isTrue); // 20 Okt
      expect(days[4].day, DateTime(2026, 10, 20));
      expect(days[5].active, isFalse);
      expect(days[5].verses, 0);
    });

    test('hari libur gratis ditandai terpisah dari hari aktif', () {
      // 22 aktif, 21 kosong (libur), 20 aktif.
      final days = ProgressService([
        _entry(now, from: 1, to: 1),
        _entry(now.subtract(const Duration(days: 2)), from: 1, to: 1),
      ]).weeklyDays(now: now);
      expect(days[5].day, DateTime(2026, 10, 21));
      expect(days[5].active, isFalse);
      expect(days[5].freeRest, isTrue);
      expect(days[5].verses, 0);
    });

    test('hari kosong kedua di minggu yang sama bukan libur', () {
      // 22 dan 19 aktif; 21 libur, 20 pemutus (jatah minggu sudah habis).
      final service = ProgressService([
        _entry(now, from: 1, to: 1),
        _entry(now.subtract(const Duration(days: 3)), from: 1, to: 1),
      ]);
      final days = service.weeklyDays(now: now);
      expect(days[5].freeRest, isTrue); // 21
      expect(days[4].freeRest, isFalse); // 20
      expect(days[4].active, isFalse);
      expect(service.snapshot(now: now, goal: DailyGoal.sedang).streak, 1);
    });

    test('libur hanya ditandai bila benar-benar menjembatani bacaan', () {
      // Hanya hari ini yang aktif: kemarin kosong bukan "libur", karena tidak
      // ada streak lebih lama yang diselamatkan.
      final days = ProgressService([
        _entry(now, from: 1, to: 1),
      ]).weeklyDays(now: now);
      expect(days[5].freeRest, isFalse); // 21
      expect(days[5].active, isFalse);
    });

    test('tanpa log: 7 hari kosong, tidak ada libur, hari ini tetap ditandai', () {
      final days = const ProgressService([]).weeklyDays(now: now);
      expect(days.length, 7);
      expect(days.any((d) => d.active), isFalse);
      expect(days.any((d) => d.freeRest), isFalse);
      expect(days.last.isToday, isTrue);
    });

    test('jumlah hari bisa diatur', () {
      expect(
        const ProgressService([]).weeklyDays(now: now, count: 3).length,
        3,
      );
    });

    test('tanggal lokal: entri 23:59 masuk hari yang sama di kalender', () {
      final days = ProgressService([
        _entry(DateTime(2026, 10, 22, 23, 59), from: 1, to: 1),
      ]).weeklyDays(now: DateTime(2026, 10, 22, 23, 59));
      expect(days.last.day, DateTime(2026, 10, 22));
      expect(days.last.active, isTrue);
    });
  });

  group('ProgressService — entri terakhir', () {
    test('log kosong: null', () {
      expect(const ProgressService([]).lastEntryOf(ActivityType.murojaah), isNull);
    });

    test('mengambil entri terbaru untuk jenis yang diminta', () {
      final service = ProgressService([
        _entry(now.subtract(const Duration(days: 3)), surah: 2, from: 1, to: 2),
        _entry(now.subtract(const Duration(days: 1)), surah: 18, from: 1, to: 5),
        _entry(now, surah: 36, from: 1, to: 3),
      ]);
      expect(service.lastEntryOf(ActivityType.murojaah)!.surahNumber, 36);
    });

    test('mengabaikan jenis lain', () {
      final service = ProgressService([
        _entry(now, surah: 2, from: 1, to: 2),
        _entry(
          now.add(const Duration(hours: 1)),
          surah: 55,
          from: 1,
          to: 2,
          type: ActivityType.quranRead,
        ),
      ]);
      expect(service.lastEntryOf(ActivityType.murojaah)!.surahNumber, 2);
      expect(service.lastEntryOf(ActivityType.quranRead)!.surahNumber, 55);
    });

    test('tidak bergantung urutan penyimpanan', () {
      final service = ProgressService([
        _entry(now, surah: 36, from: 1, to: 1),
        _entry(now.subtract(const Duration(days: 2)), surah: 2, from: 1, to: 1),
      ]);
      expect(service.lastEntryOf(ActivityType.murojaah)!.surahNumber, 36);
    });
  });

  group('ProgressService — peta hafalan', () {
    test('ayat dalam rentang ditandai, di luar tidak', () {
      final service = ProgressService([
        _entry(now, surah: 2, from: 3, to: 5),
        _entry(now, surah: 2, from: 7, to: 7),
        _entry(now, surah: 3, from: 1, to: 1),
      ]);
      expect(service.versesReadIn(2), {3, 4, 5, 7});
      expect(service.versesReadIn(3), {1});
      expect(service.versesReadIn(4), isEmpty);
    });
  });

  group('ActivityStore', () {
    test('memori: append menambah dan load mengembalikan', () async {
      final store = MemoryActivityStore();
      await store.append(_entry(now));
      await store.append(_entry(now, from: 2, to: 3));
      expect((await store.load()).length, 2);
    });

    test(
      'prefs: entri tersimpan terurut, berversi, dan bisa dibaca ulang',
      () async {
        SharedPreferences.setMockInitialValues({});
        final store = const PrefsActivityStore();
        await store.append(_entry(now, from: 1, to: 2));
        await store.append(
          _entry(now.subtract(const Duration(days: 1)), from: 1, to: 1),
        );
        final loaded = await store.load();
        expect(loaded.length, 2);
        expect(loaded.first.at.isBefore(loaded.last.at), isTrue);
        expect(loaded.last.verses, 2);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(PrefsActivityStore.key),
          contains('"version":3'),
        );
      },
    );

    test(
      'prefs: log format lama tetap terbaca dan tidak hilang saat ditambah',
      () async {
        SharedPreferences.setMockInitialValues({
          PrefsActivityStore.key:
              '[{"at":"2026-10-20T13:00:00.000Z","surah":2,"from":1,"to":7}]',
        });
        final store = const PrefsActivityStore();
        expect((await store.load()).single.surahNumber, 2);

        await store.append(_entry(now));
        final loaded = await store.load();
        expect(loaded.length, 2);
        expect(loaded.first.surahNumber, 2);
      },
    );
  });
}
