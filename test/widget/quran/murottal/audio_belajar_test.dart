import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran/Quran/data/datasources/equran_remote_datasource.dart';
import 'package:quran/Quran/data/models/surah_audio_model.dart';
import 'package:quran/Quran/data/models/tafsir_response_model.dart';
import 'package:quran/Quran/murottal/application/murottal_controller.dart';
import 'package:quran/Quran/murottal/application/qari_store.dart';
import 'package:quran/Quran/murottal/application/repeat_sequencer.dart';
import 'package:quran/Quran/murottal/presentation/widgets/mini_player.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlayer extends Fake implements AudioPlayer {
  final state = StreamController<PlayerState>.broadcast();
  final urls = <String>[];
  final speeds = <double>[];
  int seeks = 0;
  ProcessingState processing = ProcessingState.ready;

  @override
  ProcessingState get processingState => processing;
  @override
  Stream<PlayerState> get playerStateStream => state.stream;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Duration? get duration => const Duration(seconds: 5);
  @override
  Future<Duration?> setUrl(String url,
      {Map<String, String>? headers,
      Duration? initialPosition,
      bool preload = true,
      dynamic tag}) async {
    urls.add(url);
    return duration;
  }

  @override
  Future<void> setSpeed(double speed) async => speeds.add(speed);
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration? position, {int? index}) async {
    seeks++;
    processing = ProcessingState.ready; // seek menghidupkan lagi sumber yang selesai
  }
  @override
  Future<void> dispose() async {}

  void complete() {
    processing = ProcessingState.completed;
    state.add(PlayerState(true, ProcessingState.completed));
  }
}

class _FakeRemote implements EquranRemoteDataSource {
  @override
  Future<SurahAudioModel> getSurahAudio(int n) async => SurahAudioModel(
        nomor: n,
        audioFull: const {},
        ayat: [
          for (var i = 1; i <= 2; i++)
            AyatAudioModel(nomorAyat: i, audio: {'05': 's$n-a$i'}),
        ],
      );

  @override
  Future<TafsirResponseModel> getTafsir(int n) => throw UnimplementedError();

  @override
  Future<Map<int, String>> getTransliterations(int n) =>
      throw UnimplementedError();
}

MurottalController make(_FakePlayer p) => MurottalController(
      datasource: _FakeRemote(),
      qariStore: QariStore.defaults(),
      player: p,
      surahInfo: (n) => n <= 114 ? (name: 'S$n', totalAyat: 2) : null,
    );

Future<void> complete(_FakePlayer p) async {
  p.complete();
  await pumpEventQueue();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MurottalController', () {
    test('kecepatan: default 1×, setSpeed disimpan dan diterapkan', () async {
      final p = _FakePlayer();
      final c = make(p);
      await c.prefsLoaded;
      expect(c.speed.value, 1.0);
      await c.setSpeed(0.75);
      expect(p.speeds.last, 0.75);
      final c2 = make(_FakePlayer());
      await c2.prefsLoaded;
      expect(c2.speed.value, 0.75);
    });

    test('pengaturan ulang disimpan permanen; rentang tidak (BL-04-5)', () async {
      final c = make(_FakePlayer());
      await c.prefsLoaded;
      c.setRepeat(const RepeatSettings(
          mode: RepeatKind.ayat, count: 5, gapSeconds: 2));
      await pumpEventQueue();
      final c2 = make(_FakePlayer());
      await c2.prefsLoaded;
      expect(c2.repeat.value,
          const RepeatSettings(mode: RepeatKind.ayat, count: 5, gapSeconds: 2));

      c2.setRepeat(const RepeatSettings(
          mode: RepeatKind.range, count: 3, rangeStart: 2, rangeEnd: 2, gapSeconds: 5));
      await pumpEventQueue();
      final c3 = make(_FakePlayer());
      await c3.prefsLoaded;
      // Mode rentang dimuat sebagai mati; jumlah & jeda tetap.
      expect(c3.repeat.value.mode, RepeatKind.off);
      expect(c3.repeat.value.gapSeconds, 5);
      expect(c3.repeat.value.rangeStart, 1);
    });

    test('jeda tersimpan terbaca setelah prefsLoaded (Dengar-Tirukan, BL-08-7)',
        () async {
      SharedPreferences.setMockInitialValues({'murottal_repeat_gap': 5});
      final c = make(_FakePlayer());
      await c.prefsLoaded;
      expect(c.repeat.value.gapSeconds, 5);
    });

    test('kecepatan diterapkan saat memutar ayat', () async {
      SharedPreferences.setMockInitialValues({'murottal_speed': 0.5});
      final p = _FakePlayer();
      final c = make(p);
      await c.prefsLoaded;
      await c.playAyat(surahNumber: 1, surahName: 'S1', ayatNumber: 1, totalAyat: 2);
      expect(p.speeds.last, 0.5);
    });

    test('playOnce: selesai true tanpa lanjut otomatis; stop -> false', () async {
      final p = _FakePlayer();
      final c = make(p);
      await c.prefsLoaded;
      final f = c.playOnce(
          surahNumber: 1, surahName: 'S1', ayatNumber: 1, totalAyat: 2);
      await pumpEventQueue();
      await complete(p);
      expect(await f, isTrue);
      expect(c.value, isA<MurottalIdle>());
      expect(p.urls, ['s1-a1']);

      final g = c.playOnce(
          surahNumber: 1, surahName: 'S1', ayatNumber: 2, totalAyat: 2);
      await pumpEventQueue();
      await c.stop();
      expect(await g, isFalse);
    });

    test('ulang satu ayat 3×: sumber tidak dimuat ulang, lalu idle', () async {
      final p = _FakePlayer();
      final c = make(p);
      await c.prefsLoaded;
      c.setRepeat(const RepeatSettings(mode: RepeatKind.ayat, count: 3));
      await c.playAyat(surahNumber: 1, surahName: 'S1', ayatNumber: 1, totalAyat: 2);
      await complete(p);
      await complete(p);
      expect((c.value as MurottalPlaying).currentAyat, 1);
      expect(p.urls, ['s1-a1']);
      expect(p.seeks, 2);
      await complete(p);
      expect(c.value, isA<MurottalIdle>());
    });

    test('BL-04-4: pause saat jeda, ganti jeda ke 0, play -> lanjut ulangan',
        () async {
      final p = _FakePlayer();
      final c = make(p);
      await c.prefsLoaded;
      c.setRepeat(const RepeatSettings(
          mode: RepeatKind.ayat, count: 3, gapSeconds: 5));
      await c.playAyat(surahNumber: 1, surahName: 'S1', ayatNumber: 1, totalAyat: 2);
      await complete(p); // masuk jeda 5 dtk
      await c.pause();
      c.setRepeat(c.repeat.value.copyWith(gapSeconds: 0));
      await c.resume();
      await pumpEventQueue();
      expect(p.seeks, 1); // ulangan ke-2 benar-benar diputar
      expect(c.value, isA<MurottalPlaying>());
      await complete(p);
      expect(p.seeks, 2);
      await complete(p);
      expect(c.value, isA<MurottalIdle>());
    });

    test('BL-04-4: ganti jeda saat jeda berjalan (tanpa pause) tetap lanjut',
        () async {
      final p = _FakePlayer();
      final c = make(p);
      await c.prefsLoaded;
      c.setRepeat(const RepeatSettings(
          mode: RepeatKind.ayat, count: 3, gapSeconds: 5));
      await c.playAyat(surahNumber: 1, surahName: 'S1', ayatNumber: 1, totalAyat: 2);
      await complete(p);
      c.setRepeat(c.repeat.value.copyWith(gapSeconds: 0));
      await pumpEventQueue();
      expect(p.seeks, 1);
    });

    test('rentang 1..2 x2 memutar ulang dari awal', () async {
      final p = _FakePlayer();
      final c = make(p);
      await c.prefsLoaded;
      c.setRepeat(const RepeatSettings(
          mode: RepeatKind.range, count: 2, rangeStart: 1, rangeEnd: 2));
      await c.playFullSurah(surahNumber: 1, surahName: 'S1', totalAyat: 2);
      await complete(p);
      expect((c.value as MurottalPlaying).currentAyat, 2);
      await complete(p);
      expect((c.value as MurottalPlaying).currentAyat, 1);
    });

    test('auto-next ke surah berikutnya; mati = berhenti', () async {
      final p = _FakePlayer();
      final c = make(p);
      await c.prefsLoaded;
      expect(c.autoNextSurah, isTrue);
      await c.playFullSurah(surahNumber: 1, surahName: 'S1', totalAyat: 2);
      await complete(p);
      await complete(p);
      final s = c.value as MurottalPlaying;
      expect((s.surahNumber, s.currentAyat, s.surahName), (2, 1, 'S2'));

      await c.setAutoNextSurah(false);
      await c.playFullSurah(surahNumber: 1, surahName: 'S1', totalAyat: 2);
      await complete(p);
      await complete(p);
      expect(c.value, isA<MurottalIdle>());
    });

    test('ulang aktif mengalahkan auto-next', () async {
      final p = _FakePlayer();
      final c = make(p);
      await c.prefsLoaded;
      c.setRepeat(const RepeatSettings(mode: RepeatKind.ayat, count: 3));
      await c.playFullSurah(surahNumber: 1, surahName: 'S1', totalAyat: 2);
      await complete(p);
      await complete(p);
      expect((c.value as MurottalPlaying).surahNumber, 1);
    });
  });

  group('MiniPlayer', () {
    Future<(MurottalController, _FakePlayer)> pumpPlayer(
        WidgetTester tester) async {
      final p = _FakePlayer();
      final c = make(p);
      await c.prefsLoaded;
      await c.playAyat(surahNumber: 1, surahName: 'S1', ayatNumber: 1, totalAyat: 2);
      await tester.pumpWidget(QuranThemeScope(
        child: MaterialApp(home: Scaffold(body: MiniPlayer(controller: c))),
      ));
      return (c, p);
    }

    testWidgets('tombol kecepatan menampilkan dan mengganti kecepatan',
        (tester) async {
      final (c, _) = await pumpPlayer(tester);
      expect(find.text('1×'), findsOneWidget);
      expect(find.bySemanticsLabel('Kecepatan 1×'), findsOneWidget);
      final size = tester.getSize(find.byType(TextButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('1×'));
      await tester.pump();
      expect(find.text('1.25×'), findsOneWidget);
      expect(c.speed.value, 1.25);
    });

    testWidgets('tombol ulang membuka sheet dan mengubah mode', (tester) async {
      final (c, _) = await pumpPlayer(tester);
      final btn = find.bySemanticsLabel('Ulang ayat');
      expect(btn, findsOneWidget);
      final size = tester.getSize(find.byType(IconButton).last);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(find.text('Satu ayat'), findsOneWidget);
      expect(find.text('Rentang ayat'), findsOneWidget);

      final chip = tester.getSize(find.bySemanticsLabel('Ulang satu ayat'));
      expect(chip.height, greaterThanOrEqualTo(48));

      await tester.tap(find.text('Satu ayat'));
      await tester.pumpAndSettle();
      expect(c.repeat.value.mode, RepeatKind.ayat);
      expect(find.text('∞'), findsOneWidget);
      expect(find.text('5 dtk'), findsOneWidget);
      await tester.ensureVisible(find.text('∞'));
      await tester.tap(find.text('∞'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('5 dtk'));
      await tester.tap(find.text('5 dtk'));
      await tester.pumpAndSettle();
      expect(c.repeat.value.count, RepeatSettings.infinite);
      expect(c.repeat.value.gapSeconds, 5);
    });

    testWidgets('tombol punya tooltip berbahasa Indonesia', (tester) async {
      final (c, _) = await pumpPlayer(tester);
      expect(find.byTooltip('Jeda'), findsOneWidget);
      expect(find.byTooltip('Ayat sebelumnya'), findsOneWidget);
      expect(find.byTooltip('Ayat berikutnya'), findsOneWidget);
      expect(find.byTooltip('Tutup pemutar'), findsOneWidget);
      await c.pause();
      await tester.pump();
      expect(find.byTooltip('Putar'), findsOneWidget);
    });

    testWidgets('saat memuat, judul memakai nama surah', (tester) async {
      final (c, _) = await pumpPlayer(tester);
      c.value = const MurottalLoading(surahNumber: 112, surahName: 'Al-Ikhlas');
      await tester.pump();
      expect(find.text('Al-Ikhlas'), findsOneWidget);
      expect(find.text('Surah 112'), findsNothing);
    });

    testWidgets('rentang: ayat akhir tidak bisa lebih kecil dari ayat awal',
        (tester) async {
      final (c, _) = await pumpPlayer(tester);
      c.setRepeat(const RepeatSettings(
          mode: RepeatKind.range, count: 3, rangeStart: 2, rangeEnd: 2));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Ulang ayat, aktif'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ayat akhir 2'));
      await tester.pumpAndSettle();
      expect(find.text('Ayat akhir 1'), findsNothing);
    });
  });
}
