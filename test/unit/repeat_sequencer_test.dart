import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murottal/application/murottal_prefs_store.dart';
import 'package:quran/Quran/murottal/application/repeat_sequencer.dart';
import 'package:shared_preferences/shared_preferences.dart';

NextStep done(RepeatSequencer s, int ayat,
        {int surah = 1,
        int total = 7,
        bool full = true,
        bool autoNext = true}) =>
    s.onAyatCompleted(
      surah: surah,
      ayat: ayat,
      totalAyat: total,
      isFullSurah: full,
      autoNextSurah: autoNext,
    );

void main() {
  group('RepeatSequencer', () {
    test('off: lanjut ayat berikutnya', () {
      final s = RepeatSequencer();
      expect((done(s, 2) as PlayAyat).ayat, 3);
    });

    test('satu ayat 3x: diputar ulang 2 kali lalu berhenti', () {
      final s = RepeatSequencer()
        ..settings = const RepeatSettings(mode: RepeatKind.ayat, count: 3);
      expect((done(s, 4) as PlayAyat).ayat, 4);
      expect((done(s, 4) as PlayAyat).ayat, 4);
      expect(done(s, 4), isA<StopPlayback>());
    });

    test('satu ayat 1x: sekali putar lalu berhenti', () {
      final s = RepeatSequencer()
        ..settings = const RepeatSettings(mode: RepeatKind.ayat, count: 1);
      expect(done(s, 4), isA<StopPlayback>());
    });

    test('satu ayat ∞: tidak pernah berhenti', () {
      final s = RepeatSequencer()
        ..settings = const RepeatSettings(
            mode: RepeatKind.ayat, count: RepeatSettings.infinite);
      for (var i = 0; i < 50; i++) {
        expect((done(s, 4) as PlayAyat).ayat, 4);
      }
    });

    test('rentang 2..4 x2: maju dalam rentang, loop ke awal, lalu berhenti', () {
      final s = RepeatSequencer()
        ..settings = const RepeatSettings(
            mode: RepeatKind.range, count: 2, rangeStart: 2, rangeEnd: 4);
      expect((done(s, 2) as PlayAyat).ayat, 3);
      expect((done(s, 3) as PlayAyat).ayat, 4);
      expect((done(s, 4) as PlayAyat).ayat, 2); // putaran ke-2
      expect((done(s, 2) as PlayAyat).ayat, 3);
      expect((done(s, 3) as PlayAyat).ayat, 4);
      expect(done(s, 4), isA<StopPlayback>());
    });

    test('jeda hanya dipakai antar ulangan, bukan antar ayat dalam rentang', () {
      final s = RepeatSequencer()
        ..settings = const RepeatSettings(
            mode: RepeatKind.range,
            count: 3,
            rangeStart: 1,
            rangeEnd: 2,
            gapSeconds: 5);
      expect((done(s, 1) as PlayAyat).gap, Duration.zero);
      expect((done(s, 2) as PlayAyat).gap, const Duration(seconds: 5));
      final a = RepeatSequencer()
        ..settings = const RepeatSettings(
            mode: RepeatKind.ayat, count: 3, gapSeconds: 2);
      expect((done(a, 1) as PlayAyat).gap, const Duration(seconds: 2));
    });

    test('rentang di luar jumlah ayat dijepit', () {
      final s = RepeatSequencer()
        ..settings = const RepeatSettings(
            mode: RepeatKind.range, count: 3, rangeStart: 2, rangeEnd: 99);
      expect(((done(s, 7)) as PlayAyat).ayat, 2);
    });

    test('auto-next: ayat terakhir full surah lanjut ke surah berikutnya', () {
      final s = RepeatSequencer();
      expect((done(s, 7, surah: 1) as PlaySurah).surah, 2);
    });

    test('auto-next mati atau bukan full surah: berhenti', () {
      final s = RepeatSequencer();
      expect(done(s, 7, autoNext: false), isA<StopPlayback>());
      expect(done(s, 7, full: false), isA<StopPlayback>());
    });

    test('surah 114 berhenti', () {
      final s = RepeatSequencer();
      expect(done(s, 6, surah: 114, total: 6), isA<StopPlayback>());
    });

    test('ulang aktif mengalahkan auto-next', () {
      final s = RepeatSequencer()
        ..settings = const RepeatSettings(mode: RepeatKind.ayat, count: 3);
      expect(done(s, 7), isA<PlayAyat>());
      final r = RepeatSequencer()
        ..settings = const RepeatSettings(
            mode: RepeatKind.range, count: 1, rangeStart: 5, rangeEnd: 7);
      expect(done(r, 7), isA<StopPlayback>()); // bukan PlaySurah
    });

    test('reset memulai hitungan dari awal', () {
      final s = RepeatSequencer()
        ..settings = const RepeatSettings(mode: RepeatKind.ayat, count: 2);
      expect(done(s, 1), isA<PlayAyat>());
      s.reset();
      expect(done(s, 1), isA<PlayAyat>());
    });
  });

  group('MurottalPrefsStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    const store = MurottalPrefsStore();

    test('default: 1× dan auto-next aktif', () async {
      expect(await store.loadSpeed(), 1.0);
      expect(await store.loadAutoNext(), isTrue);
    });

    test('tersimpan dan dipulihkan', () async {
      await store.saveSpeed(0.75);
      await store.saveAutoNext(false);
      expect(await store.loadSpeed(), 0.75);
      expect(await store.loadAutoNext(), isFalse);
    });

    test('nilai kecepatan tidak valid kembali ke 1×', () async {
      SharedPreferences.setMockInitialValues({MurottalPrefsStore.keySpeed: 3.0});
      expect(await store.loadSpeed(), 1.0);
    });
  });
}
