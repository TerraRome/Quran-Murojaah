import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/progress/activity_entry.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_controller.dart';
import 'package:quran/Quran/murojaah/progress/reading_log_recorder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Clock {
  DateTime now = DateTime(2026, 10, 22, 9);

  void advance(Duration d) => now = now.add(d);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Clock clock;
  late MemoryActivityStore store;
  late MurojaahProgressController progress;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = _Clock();
    store = MemoryActivityStore();
    progress = MurojaahProgressController(store: store);
    await progress.load();
  });

  ReadingLogRecorder recorder({ActivityType type = ActivityType.quranRead}) =>
      ReadingLogRecorder(
        progress: progress,
        type: type,
        clock: () => clock.now,
      );

  group('ambang waktu', () {
    test('kurang dari 5 detik: tidak dapat kredit', () async {
      final r = recorder();
      r.enter('1:1', surahNumber: 1, verse: 1);
      clock.advance(const Duration(seconds: 4));
      r.leave('1:1');
      await r.flush();
      expect(progress.entries, isEmpty);
      expect(r.pendingCount, 0);
    });

    test('tepat 5 detik: dapat kredit', () async {
      final r = recorder();
      r.enter('1:1', surahNumber: 1, verse: 1);
      clock.advance(ReadingLogRecorder.defaultDwell);
      r.leave('1:1');
      await r.flush();
      expect(progress.entries.length, 1);
      expect(progress.entries.single.verses, 1);
      expect(progress.entries.single.type, ActivityType.quranRead);
    });

    test('ambang bisa diatur', () async {
      final r = ReadingLogRecorder(
        progress: progress,
        type: ActivityType.quranRead,
        dwell: const Duration(seconds: 1),
        clock: () => clock.now,
      );
      r.enter('1:1', surahNumber: 1, verse: 1);
      clock.advance(const Duration(seconds: 1));
      r.leave('1:1');
      await r.flush();
      expect(progress.entries.length, 1);
    });

    test('default 5 detik', () {
      expect(ReadingLogRecorder.defaultDwell, const Duration(seconds: 5));
    });
  });

  group('Tandai sudah dibaca', () {
    test('menandai semua item yang tampil tanpa menunggu waktu', () async {
      final r = recorder();
      r.enter('1:1', surahNumber: 1, verse: 1);
      r.enter('1:2', surahNumber: 1, verse: 2);
      r.enter('1:3', surahNumber: 1, verse: 3);
      r.markVisibleAsRead();
      await r.flush();

      expect(progress.entries.length, 1);
      expect(progress.entries.single.fromVerse, 1);
      expect(progress.entries.single.toVerse, 3);
    });

    test('ayat tidak berurutan jadi beberapa rentang', () async {
      final r = recorder();
      r.enter('1:1', surahNumber: 1, verse: 1);
      r.enter('1:2', surahNumber: 1, verse: 2);
      r.enter('1:5', surahNumber: 1, verse: 5);
      r.markVisibleAsRead();
      await r.flush();

      final ranges = [
        for (final e in progress.entries) '${e.fromVerse}-${e.toVerse}',
      ];
      expect(ranges, ['1-2', '5-5']);
    });

    test('item yang sudah dikredit tidak dikredit dua kali', () async {
      final r = recorder();
      r.enter('1:1', surahNumber: 1, verse: 1);
      r.markVisibleAsRead();
      r.markVisibleAsRead();
      await r.flush();
      expect(progress.entries.length, 1);
    });
  });

  group('lifecycle', () {
    test('pause tidak memberi kredit untuk item yang belum cukup lama', () async {
      final r = recorder();
      r.enter('1:1', surahNumber: 1, verse: 1);
      clock.advance(const Duration(seconds: 2));
      r.handleLifecycle(AppLifecycleState.paused);
      await r.flush();

      expect(progress.entries, isEmpty);
      expect(r.visibleKeys, isEmpty);
      expect(r.isPaused, isTrue);
    });

    test('pause tetap menulis item yang sudah lewat ambang', () async {
      final r = recorder();
      r.enter('1:1', surahNumber: 1, verse: 1);
      r.enter('1:2', surahNumber: 1, verse: 2);
      clock.advance(const Duration(seconds: 6));
      r.handleLifecycle(AppLifecycleState.paused);
      await r.flush();

      expect(progress.entries.length, 1);
      expect(progress.entries.single.fromVerse, 1);
      expect(progress.entries.single.toVerse, 2);
    });

    test('resume memulai hitungan ulang dari nol', () async {
      final r = recorder();
      r.enter('1:1', surahNumber: 1, verse: 1);
      clock.advance(const Duration(seconds: 3));
      r.handleLifecycle(AppLifecycleState.paused);
      clock.advance(const Duration(seconds: 30));
      r.handleLifecycle(AppLifecycleState.resumed);

      // Widget mendengar notifikasi resume lalu mendaftar ulang.
      r.enter('1:1', surahNumber: 1, verse: 1);
      clock.advance(const Duration(seconds: 4));
      r.leave('1:1');
      await r.flush();
      expect(progress.entries, isEmpty);

      r.enter('1:1', surahNumber: 1, verse: 1);
      clock.advance(const Duration(seconds: 5));
      r.leave('1:1');
      await r.flush();
      expect(progress.entries.length, 1);
    });

    test('waktu di background tidak dihitung sebagai dwell', () async {
      final r = recorder();
      r.enter('1:1', surahNumber: 1, verse: 1);
      r.handleLifecycle(AppLifecycleState.paused);
      clock.advance(const Duration(minutes: 10));
      r.handleLifecycle(AppLifecycleState.resumed);
      r.enter('1:1', surahNumber: 1, verse: 1);
      clock.advance(const Duration(seconds: 3));
      r.leave('1:1');
      await r.flush();
      expect(progress.entries, isEmpty);
    });

    test('inactive juga membekukan dwell', () async {
      final r = recorder();
      r.enter('1:1', surahNumber: 1, verse: 1);
      clock.advance(const Duration(seconds: 6));
      r.handleLifecycle(AppLifecycleState.inactive);
      await r.flush();
      expect(progress.entries.length, 1);
    });
  });

  group('dedupe harian', () {
    test('ayat sama di sesi berbeda hari sama tidak tercatat dua kali', () async {
      final a = recorder();
      a.enter('1:1', surahNumber: 1, verse: 1);
      a.markVisibleAsRead();
      await a.flush();

      final b = recorder();
      b.enter('1:1', surahNumber: 1, verse: 1);
      b.markVisibleAsRead();
      await b.flush();

      expect(progress.entries.length, 1);
    });

    test('ayat sama di hari berbeda tetap tercatat', () async {
      final a = recorder();
      a.enter('1:1', surahNumber: 1, verse: 1);
      a.markVisibleAsRead();
      await a.flush();

      clock.advance(const Duration(days: 1));
      final b = recorder();
      b.enter('1:1', surahNumber: 1, verse: 1);
      b.markVisibleAsRead();
      await b.flush();

      expect(progress.entries.length, 2);
    });
  });

  group('tafsir dan doa', () {
    test('tafsir satu ayat memberi kredit satu ayat', () async {
      final r = recorder(type: ActivityType.tafsir);
      r.enter('tafsir:3', surahNumber: 2, verse: 3);
      r.markVisibleAsRead();
      await r.flush();

      final e = progress.entries.single;
      expect(e.type, ActivityType.tafsir);
      expect(e.surahNumber, 2);
      expect(e.fromVerse, 3);
    });

    test('doa memakai refId dan tidak mengubah ayat surah', () async {
      final r = recorder(type: ActivityType.doa);
      r.enter('doa:7', refId: '7');
      r.markVisibleAsRead();
      await r.flush();

      final e = progress.entries.single;
      expect(e.type, ActivityType.doa);
      expect(e.refId, '7');
      expect(e.surahNumber, ActivityEntry.noSurah);
      expect(e.count, 1);
    });

    test('doa yang sama dua kali sehari dihitung sekali', () async {
      for (var i = 0; i < 2; i++) {
        final r = recorder(type: ActivityType.doa);
        r.enter('doa:7', refId: '7');
        r.markVisibleAsRead();
        await r.flush();
      }
      expect(progress.entries.length, 1);
    });
  });

  test('tanpa progress: tidak menulis dan tidak melempar', () async {
    final r = ReadingLogRecorder(
      progress: null,
      type: ActivityType.quranRead,
      clock: () => clock.now,
    );
    r.enter('1:1', surahNumber: 1, verse: 1);
    r.markVisibleAsRead();
    await r.flush();
    expect(store.load(), completion(isEmpty));
  });
}
