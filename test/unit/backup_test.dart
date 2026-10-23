import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/backup/backup_controller.dart';
import 'package:quran/Quran/murojaah/backup/backup_document.dart';
import 'package:quran/Quran/murojaah/progress/activity_entry.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_controller.dart';
import 'package:quran/Quran/murojaah/progress/progress_service.dart';
import 'package:quran/Quran/murojaah/reminder/reminder_controller.dart';
import 'package:quran/Quran/murojaah/reminder/reminder_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeScheduler implements ReminderScheduler {
  _FakeScheduler({this.granted = true});

  bool granted;
  final List<({int id, DateTime at, String title, String body})> scheduled = [];

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async => scheduled.add((id: id, at: at, title: title, body: body));

  @override
  Future<void> cancel() async => scheduled.clear();

  @override
  Future<void> openSystemSettings() async {}
}

ActivityEntry entry({
  required String id,
  required DateTime at,
  int surah = 1,
  int from = 1,
  int to = 1,
  ActivityType type = ActivityType.murojaah,
  double? accuracy,
}) => ActivityEntry(
  id: id,
  at: at,
  surahNumber: surah,
  fromVerse: from,
  toVerse: to,
  type: type,
  accuracy: accuracy,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeScheduler scheduler;
  late MemoryActivityStore store;
  late MurojaahProgressController progress;
  late MurojaahReminder reminder;
  late MurojaahBackup backup;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    scheduler = _FakeScheduler();
    store = MemoryActivityStore();
    progress = MurojaahProgressController(store: store);
    await progress.load();
    reminder = MurojaahReminder(
      scheduler: scheduler,
      clock: () => DateTime(2026, 10, 23, 9),
    );
    await reminder.load();
    backup = MurojaahBackup(progress: progress, reminder: reminder);
  });

  Future<void> seed() async {
    await progress.record(
      surahNumber: 1,
      fromVerse: 1,
      toVerse: 3,
      at: DateTime(2026, 10, 20, 8),
    );
    await progress.setGoal(DailyGoal.serius);
    await reminder.setTime(21, 30);
    await reminder.setEnabled(true);
  }

  test('ekspor lalu impor menghasilkan snapshot yang sama', () async {
    await seed();
    final before = progress.snapshot(now: DateTime(2026, 10, 23, 9));
    final json = backup.exportJson();

    // Perangkat baru: log kosong, target default, pengingat mati.
    final freshStore = MemoryActivityStore();
    final freshProgress = MurojaahProgressController(store: freshStore);
    await freshProgress.load();
    final freshScheduler = _FakeScheduler();
    final freshReminder = MurojaahReminder(
      scheduler: freshScheduler,
      clock: () => DateTime(2026, 10, 23, 9),
    );
    await freshReminder.load();
    final freshBackup = MurojaahBackup(
      progress: freshProgress,
      reminder: freshReminder,
    );

    final parsed = freshBackup.parse(json);
    expect(parsed, isA<BackupOk>());
    await freshBackup.import((parsed as BackupOk).document);

    final after = freshProgress.snapshot(now: DateTime(2026, 10, 23, 9));
    expect(after.todayVerses, before.todayVerses);
    expect(after.streak, before.streak);
    expect(after.totalXp, before.totalXp);
    expect(after.goal, DailyGoal.serius);
    expect(freshProgress.entries.map((e) => e.id).toSet(), {
      for (final e in progress.entries) e.id,
    });
    expect(freshReminder.enabled, isTrue);
    expect(freshReminder.timeLabel, '21:30');
    // Jadwal dibangun ulang dari pengaturan yang dipulihkan.
    expect(freshScheduler.scheduled, isNotEmpty);
  });

  test('impor idempoten: dua kali tidak menggandakan entri', () async {
    await seed();
    final json = backup.exportJson();
    final document = (backup.parse(json) as BackupOk).document;

    final first = await backup.import(document);
    final second = await backup.import(document);

    expect(first, 0); // semua entri sudah ada di perangkat ini
    expect(second, 0);
    expect(progress.entries.length, 1);
  });

  test('impor menggabung dengan data lama tanpa menimpa', () async {
    await seed();
    final other = entry(id: 'baru-1', at: DateTime(2026, 10, 22, 7));
    final document = BackupDocument(
      entries: [
        // Entri id sama dengan yang sudah ada, isi berbeda → harus diabaikan.
        entry(id: progress.entries.first.id, at: DateTime(2026, 1, 1)),
        other,
      ],
      goalVerses: 5,
      reminderEnabled: false,
      reminderHour: 18,
      reminderMinute: 0,
    );

    expect(backup.countNew(document), 1);
    final added = await backup.import(document);

    expect(added, 1);
    expect(progress.entries.length, 2);
    // Entri lama tidak ditimpa: tanggalnya tetap.
    expect(
      progress.entries.firstWhere((e) => e.id == 'baru-1').at.day,
      22,
    );
    expect(
      progress.entries.firstWhere((e) => e.id != 'baru-1').at.year,
      2026,
    );
  });

  test('versi tidak cocok ditolak dengan pesan ramah', () async {
    final future = decodeBackup(
      '{"app":"quran-murojaah","backupVersion":99,'
      '"activitySchemaVersion":3,"entries":[]}',
    );
    expect(future, isA<BackupInvalid>());
    expect((future as BackupInvalid).message, contains('versi lebih baru'));

    final oldSchema = decodeBackup(
      '{"app":"quran-murojaah","backupVersion":1,'
      '"activitySchemaVersion":99,"entries":[]}',
    );
    expect(oldSchema, isA<BackupInvalid>());
    expect((oldSchema as BackupInvalid).message, contains('versi lebih baru'));
  });

  test('berkas rusak ditolak tanpa melempar', () async {
    for (final raw in [
      '',
      '   ',
      'bukan json',
      '[]',
      '{}',
      '{"app":"aplikasi-lain","backupVersion":1,"entries":[]}',
      '{"app":"quran-murojaah","backupVersion":1,'
          '"activitySchemaVersion":3,"entries":"bukan list"}',
      '{"app":"quran-murojaah","backupVersion":1,'
          '"activitySchemaVersion":3,"entries":[{"at":"rusak"}]}',
    ]) {
      final parsed = decodeBackup(raw);
      expect(parsed, isA<BackupInvalid>(), reason: 'input: $raw');
      expect((parsed as BackupInvalid).message, isNotEmpty);
    }
  });

  test('entri rusak sebagian dilewati, sisanya tetap masuk', () async {
    final good = entry(id: 'ok-1', at: DateTime(2026, 10, 21, 8)).toJson();
    final parsed = decodeBackup(
      '{"app":"quran-murojaah","backupVersion":1,'
      '"activitySchemaVersion":3,"goalVerses":15,'
      '"reminder":{"enabled":false,"hour":20,"minute":0},'
      '"entries":[{"at":"rusak"},${jsonEncode(good)}]}',
    );

    expect(parsed, isA<BackupOk>());
    expect((parsed as BackupOk).document.entries.length, 1);
  });

  test('target dan jam tidak valid jatuh ke default, bukan crash', () async {
    final parsed = decodeBackup(
      '{"app":"quran-murojaah","backupVersion":1,'
      '"activitySchemaVersion":3,"goalVerses":-4,'
      '"reminder":{"enabled":true,"hour":99,"minute":-1},"entries":[]}',
    );

    expect(parsed, isA<BackupOk>());
    final document = (parsed as BackupOk).document;
    expect(document.goalVerses, 15);
    expect(document.reminderHour, 20);
    expect(document.reminderMinute, 0);
    expect(document.reminderEnabled, isTrue);
  });

  test('ringkasan impor menyebut jumlah entri baru', () {
    expect(importSummary(0), contains('Tidak ada entri baru'));
    expect(importSummary(3), contains('3 entri baru'));
  });
}
