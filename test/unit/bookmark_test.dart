import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/application/bookmark.dart';
import 'package:quran/Quran/application/bookmark_controller.dart';
import 'package:quran/Quran/murojaah/backup/backup_controller.dart';
import 'package:quran/Quran/murojaah/backup/backup_document.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_controller.dart';
import 'package:quran/Quran/murojaah/reminder/reminder_controller.dart';
import 'package:quran/Quran/murojaah/reminder/reminder_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopScheduler implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<void> openSystemSettings() async {}
}

Future<MurojaahBackup> _backupWith(BookmarkController bookmarks) async {
  final progress = MurojaahProgressController(store: MemoryActivityStore());
  await progress.load();
  final reminder = MurojaahReminder(
    scheduler: _NoopScheduler(),
    clock: () => DateTime(2026, 10, 23, 9),
  );
  await reminder.load();
  return MurojaahBackup(
    progress: progress,
    reminder: reminder,
    bookmarks: bookmarks,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('BookmarkController', () {
    test('toggle menyimpan lalu menghapus', () async {
      final c = BookmarkController();
      expect(await c.toggle(2, 255), isTrue);
      expect(c.isSaved(2, 255), isTrue);
      expect(await c.toggle(2, 255), isFalse);
      expect(c.isSaved(2, 255), isFalse);
      expect(c.items, isEmpty);
    });

    test('terbaru di atas', () async {
      final c = BookmarkController();
      await c.toggle(1, 1, at: DateTime(2026, 1, 1));
      await c.toggle(36, 5, at: DateTime(2026, 1, 3));
      await c.toggle(2, 255, at: DateTime(2026, 1, 2));
      expect([for (final b in c.items) '${b.surah}:${b.ayat}'], [
        '36:5',
        '2:255',
        '1:1',
      ]);
    });

    test('hapus lalu pulihkan lewat merge: kembali ke posisi semula', () async {
      final c = BookmarkController();
      await c.toggle(1, 1, at: DateTime(2026, 1, 1));
      await c.toggle(2, 255, at: DateTime(2026, 1, 2));
      await c.toggle(36, 5, at: DateTime(2026, 1, 3));
      final removed = c.items[1];
      await c.remove(removed.surah, removed.ayat);
      await c.merge([removed]);
      expect([for (final b in c.items) '${b.surah}:${b.ayat}'], [
        '36:5',
        '2:255',
        '1:1',
      ]);
      expect(c.items[1].savedAt, DateTime(2026, 1, 2));
    });

    test('simpan sebelum load selesai tidak menimpa daftar tersimpan', () async {
      final first = BookmarkController();
      await first.toggle(1, 1, at: DateTime(2026, 1, 1));

      final c = BookmarkController();
      final loading = c.load(); // sengaja tidak ditunggu
      await c.toggle(2, 255, at: DateTime(2026, 1, 2));
      await loading;

      final reloaded = BookmarkController();
      await reloaded.load();
      expect(reloaded.isSaved(1, 1), isTrue);
      expect(reloaded.isSaved(2, 255), isTrue);
    });

    test('bertahan setelah dimuat ulang', () async {
      final c = BookmarkController();
      await c.toggle(2, 255, at: DateTime(2026, 1, 2));
      final reloaded = BookmarkController();
      await reloaded.load();
      expect(reloaded.isSaved(2, 255), isTrue);
      expect(
        reloaded.items.single.savedAt.isAtSameMomentAs(DateTime(2026, 1, 2)),
        isTrue,
      );
    });

    test('remove menghapus satu ayat dan memberi tahu listener', () async {
      final c = BookmarkController();
      await c.toggle(1, 1);
      await c.toggle(1, 2);
      var notified = 0;
      c.addListener(() => notified++);
      await c.remove(1, 1);
      expect(c.isSaved(1, 1), isFalse);
      expect(c.isSaved(1, 2), isTrue);
      expect(notified, 1);
    });

    test('data rusak di penyimpanan jadi daftar kosong', () async {
      SharedPreferences.setMockInitialValues({'quran_bookmarks': '{bukan list'});
      final c = BookmarkController();
      await c.load();
      expect(c.items, isEmpty);
    });
  });

  group('cadangan dengan bookmark', () {
    test('round-trip: bookmark ikut diekspor dan dipulihkan', () async {
      final source = BookmarkController();
      await source.toggle(2, 255, at: DateTime(2026, 1, 2));
      await source.toggle(36, 1, at: DateTime(2026, 1, 3));
      final json = (await _backupWith(source)).exportJson();

      SharedPreferences.setMockInitialValues({});
      final target = BookmarkController();
      final backup = await _backupWith(target);
      final parsed = backup.parse(json);
      expect(parsed, isA<BackupOk>());
      await backup.import((parsed as BackupOk).document);

      expect([for (final b in target.items) '${b.surah}:${b.ayat}'], [
        '36:1',
        '2:255',
      ]);
    });

    test('cadangan lama tanpa kunci bookmark tetap bisa dipulihkan', () async {
      final target = BookmarkController();
      await target.toggle(1, 1);
      final backup = await _backupWith(target);
      const old = '{"app":"quran-murojaah","backupVersion":1,'
          '"activitySchemaVersion":1,"goalVerses":15,'
          '"reminder":{"enabled":false,"hour":20,"minute":0},"entries":[]}';
      final parsed = backup.parse(old);
      expect(parsed, isA<BackupOk>());
      expect((parsed as BackupOk).document.bookmarks, isEmpty);
      await backup.import(parsed.document);
      // Bookmark perangkat tidak disentuh.
      expect(target.isSaved(1, 1), isTrue);
      expect(target.items.length, 1);
    });

    test('bookmark rusak di berkas dilewati', () {
      final doc = BackupDocument(
        entries: const [],
        goalVerses: 15,
        reminderEnabled: false,
        reminderHour: 20,
        reminderMinute: 0,
        bookmarks: [Bookmark(surah: 1, ayat: 1, savedAt: DateTime(2026))],
      );
      final map = doc.toJson();
      (map['bookmarks']! as List).add({'surah': 'x'});
      map['entries'] = [];
      final parsed = decodeBackup(jsonEncode(map));
      expect((parsed as BackupOk).document.bookmarks.length, 1);
    });
  });
}
