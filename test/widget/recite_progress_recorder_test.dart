import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_controller.dart';
import 'package:quran/Quran/murojaah/progress/progress_service.dart';
import 'package:quran/Quran/murojaah/recite/recite_progress_recorder.dart';
import 'package:quran/Quran/murojaah/recite/recite_session_controller.dart';
import 'package:quran/Quran/murojaah/recite/recite_session_engine.dart';
import 'package:recite_quran/recite_quran.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Engine palsu: dua ayat, dua kata per ayat.
class _FakeEngine implements ReciteSessionEngine {
  static const phonemes = ['اا', 'بب', 'جج', 'دد'];

  @override
  final List<String> wordPhonemes = phonemes;

  @override
  final List<int> wordAyahStarts = const [0, 2, 4];

  @override
  final ValueNotifier<ReciteMurojaahStatus> status = ValueNotifier(
    ReciteMurojaahStatus.ready,
  );

  @override
  final ValueNotifier<String?> errorMessage = ValueNotifier(null);

  @override
  final ValueNotifier<double> downloadProgress = ValueNotifier(0);

  @override
  Stream<WordMatchedEvent> get wordEvents => const Stream.empty();

  @override
  Stream<String> get transcript => const Stream.empty();

  @override
  String phonemesOf(int wordId) =>
      wordId >= 0 && wordId < wordPhonemes.length ? wordPhonemes[wordId] : '';

  @override
  late List<QuranVerse> verses = [
    _verse(1, ['اا', 'بب']),
    _verse(2, ['جج', 'دد']),
  ];

  static QuranVerse _verse(int ayah, List<String> words) => QuranVerse(
    surah: 1,
    ayah: ayah,
    textUthmani: words.join(' '),
    uthmaniWords: words,
    textPhoneme: words.join(),
    phonemeWords: words,
    surahName: 'الفاتحة',
    surahNameEn: 'Al-Fatihah',
  );

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}

  @override
  void rewindTo(int globalWordIndex) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 22, 20);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ({
    ReciteSessionController session,
    ReciteProgressRecorder recorder,
    MurojaahProgressController progress,
  })
  build({bool withProgress = true}) {
    final engine = _FakeEngine();
    final session = ReciteSessionController(engine: engine);
    session.adoptVerses();
    final progress = MurojaahProgressController(store: MemoryActivityStore());
    return (
      session: session,
      recorder: ReciteProgressRecorder(
        progress: withProgress ? progress : null,
        surahNumber: 1,
        clock: () => now,
      ),
      progress: progress,
    );
  }

  test('tanpa progres: tidak ada yang dicatat, tidak melempar', () async {
    final h = build(withProgress: false);
    await h.recorder.record(h.session);
    expect(h.recorder.recorded, isEmpty);
  });

  test('satu ayat tuntas dicatat sebagai satu rentang', () async {
    final h = build();
    h.session.onWordEvent(WordMatchedEvent(wordId: 0, cleanAsr: 'اا'));
    h.session.onWordEvent(WordMatchedEvent(wordId: 1, cleanAsr: 'بب'));
    await h.recorder.record(h.session);

    final entries = h.progress.entries;
    expect(entries.length, 1);
    expect(entries.single.fromVerse, 1);
    expect(entries.single.toVerse, 1);
    expect(entries.single.accuracy, 1.0);
    expect(h.progress.snapshot(now: now).todayVerses, 1);
  });

  test('dua ayat berurutan digabung jadi satu entri', () async {
    final h = build();
    for (var id = 0; id < 4; id++) {
      h.session.onWordEvent(
        WordMatchedEvent(wordId: id, cleanAsr: _FakeEngine.phonemes[id]),
      );
    }
    await h.recorder.record(h.session);
    expect(h.progress.entries.length, 1);
    expect(h.progress.entries.single.fromVerse, 1);
    expect(h.progress.entries.single.toVerse, 2);
  });

  test('ayat yang tidak berurutan dicatat sebagai rentang terpisah', () async {
    final h = build();
    // Ayat 2 tuntas duluan, lalu ayat 1.
    for (var id = 2; id < 4; id++) {
      h.session.onWordEvent(
        WordMatchedEvent(wordId: id, cleanAsr: _FakeEngine.phonemes[id]),
      );
    }
    await h.recorder.record(h.session);
    expect(h.progress.entries.length, 1);
    expect(h.progress.entries.single.fromVerse, 2);

    for (var id = 0; id < 2; id++) {
      h.session.onWordEvent(
        WordMatchedEvent(wordId: id, cleanAsr: _FakeEngine.phonemes[id]),
      );
    }
    await h.recorder.record(h.session);
    expect(h.progress.entries.length, 2);
    expect(h.progress.entries.last.fromVerse, 1);
    expect(h.progress.entries.last.toVerse, 1);
  });

  test('ayat yang sama tidak tercatat dua kali', () async {
    final h = build();
    for (var id = 0; id < 2; id++) {
      h.session.onWordEvent(
        WordMatchedEvent(wordId: id, cleanAsr: _FakeEngine.phonemes[id]),
      );
    }
    await h.recorder.record(h.session);
    await h.recorder.record(
      h.session,
    ); // mis. lifecycle paused setelah berhenti
    await h.recorder.record(h.session);
    expect(h.progress.entries.length, 1);
    expect(h.progress.snapshot(now: now).todayVerses, 1);
  });

  test(
    'pencatatan berulang setelah ayat baru hanya menambah ayat baru',
    () async {
      final h = build();
      for (var id = 0; id < 2; id++) {
        h.session.onWordEvent(
          WordMatchedEvent(wordId: id, cleanAsr: _FakeEngine.phonemes[id]),
        );
      }
      await h.recorder.record(h.session);
      for (var id = 2; id < 4; id++) {
        h.session.onWordEvent(
          WordMatchedEvent(wordId: id, cleanAsr: _FakeEngine.phonemes[id]),
        );
      }
      await h.recorder.record(h.session);
      expect(h.progress.entries.length, 2);
      expect(h.progress.snapshot(now: now).todayVerses, 2);
    },
  );

  test('akurasi sesi ikut tercatat dan menentukan XP', () async {
    final h = build();
    // 2 benar, 1 salah → akurasi 2/3 < 90%.
    h.session.onWordEvent(WordMatchedEvent(wordId: 0, cleanAsr: 'اا'));
    h.session.onWordEvent(
      WordMatchedEvent(wordId: 1, cleanAsr: 'zz', isRed: true),
    );
    // Ayat 1 belum tuntas (ada kata merah) → tidak dicatat sama sekali.
    await h.recorder.record(h.session);
    expect(h.progress.entries, isEmpty);
  });

  test('akurasi rendah tetap dicatat sebagai aktivitas tanpa XP', () async {
    final h = build();
    // Ayat 1 tuntas, tapi ada kesalahan di ayat 2 → akurasi 4/5 = 0.8.
    for (var id = 0; id < 2; id++) {
      h.session.onWordEvent(
        WordMatchedEvent(wordId: id, cleanAsr: _FakeEngine.phonemes[id]),
      );
    }
    h.session.onWordEvent(
      WordMatchedEvent(wordId: 2, cleanAsr: 'zz', isRed: true),
    );
    await h.recorder.record(h.session);

    expect(h.progress.entries.single.accuracy, lessThan(0.9));
    final snap = h.progress.snapshot(now: now);
    expect(snap.todayVerses, 1);
    expect(snap.todayXp, 0);
    expect(snap.streak, 1);
  });

  test('hasil sesi diakumulasi dan bisa dibaca berkali-kali', () async {
    final h = build();
    for (var id = 0; id < 2; id++) {
      h.session.onWordEvent(
        WordMatchedEvent(wordId: id, cleanAsr: _FakeEngine.phonemes[id]),
      );
    }
    final first = await h.recorder.record(h.session);
    expect(first.xpGained, 5);
    expect(first.streakIncreased, isTrue);
    expect(h.recorder.result.xpGained, 5);

    // Pencatatan ulang tanpa ayat baru tidak menggandakan hasil.
    final second = await h.recorder.record(h.session);
    expect(second.xpGained, 5);
    expect(h.recorder.result.xpGained, 5);
  });

  test('hasil sesi: streak naik hanya pada sesi pertama hari itu', () async {
    final progress = MurojaahProgressController(store: MemoryActivityStore());

    Future<ReciteProgressRecorder> runSession() async {
      final session = ReciteSessionController(engine: _FakeEngine());
      session.adoptVerses();
      for (var id = 0; id < 2; id++) {
        session.onWordEvent(
          WordMatchedEvent(wordId: id, cleanAsr: _FakeEngine.phonemes[id]),
        );
      }
      final recorder = ReciteProgressRecorder(
        progress: progress,
        surahNumber: 1,
      );
      await recorder.record(session);
      return recorder;
    }

    final first = await runSession();
    final second = await runSession();

    expect(first.result.streakIncreased, isTrue);
    expect(second.result.streakIncreased, isFalse);
    expect(second.result.xpGained, 0); // ayat yang sama tidak memberi XP lagi
  });

  test('recorded mencatat ayat yang sudah masuk log', () async {
    final h = build();
    for (var id = 0; id < 2; id++) {
      h.session.onWordEvent(
        WordMatchedEvent(wordId: id, cleanAsr: _FakeEngine.phonemes[id]),
      );
    }
    await h.recorder.record(h.session);
    expect(h.recorder.recorded, {0});
  });
}
