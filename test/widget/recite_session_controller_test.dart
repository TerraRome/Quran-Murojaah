import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/recite/recite_session_controller.dart';
import 'package:quran/Quran/murojaah/recite/recite_session_engine.dart';
import 'package:recite_quran/recite_quran.dart';

/// Engine palsu: meniru bentuk data `ReciteMurojaahService` tanpa mesin ASR.
class _FakeEngine implements ReciteSessionEngine {
  _FakeEngine({required this.wordPhonemes, required this.wordAyahStarts});

  @override
  final List<String> wordPhonemes;

  @override
  final List<int> wordAyahStarts;

  @override
  final ValueNotifier<ReciteMurojaahStatus> status =
      ValueNotifier(ReciteMurojaahStatus.ready);

  @override
  final ValueNotifier<String?> errorMessage = ValueNotifier(null);

  @override
  final ValueNotifier<double> downloadProgress = ValueNotifier(0);

  final _words = StreamController<WordMatchedEvent>.broadcast();
  final _text = StreamController<String>.broadcast();

  final List<int> rewindCalls = [];
  int stopCalls = 0;
  int startCalls = 0;

  @override
  Stream<WordMatchedEvent> get wordEvents => _words.stream;

  @override
  Stream<String> get transcript => _text.stream;

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

  void emitWord(WordMatchedEvent event) => _words.add(event);
  void emitTranscript(String text) => _text.add(text);

  @override
  Future<void> startListening() async => startCalls++;

  @override
  Future<void> stopListening() async => stopCalls++;

  @override
  void rewindTo(int globalWordIndex) => rewindCalls.add(globalWordIndex);
}

WordMatchedEvent _green(int wordId, String cleanAsr) =>
    WordMatchedEvent(wordId: wordId, cleanAsr: cleanAsr);

WordMatchedEvent _red(int wordId) =>
    WordMatchedEvent(wordId: wordId, cleanAsr: '', isRed: true);

/// Controller dengan 2 ayat × 2 kata; kata global 0..3.
({_FakeEngine engine, ReciteSessionController session}) _setup() {
  final engine = _FakeEngine(
    wordPhonemes: const ['اا', 'بب', 'جج', 'دد'],
    wordAyahStarts: const [0, 2, 4],
  );
  final session = ReciteSessionController(engine: engine)..adoptVerses();
  return (engine: engine, session: session);
}

void main() {
  testWidgets('akurasi 100% sebelum ada percobaan', (tester) async {
    final s = _setup();
    expect(s.session.accuracy, 1);
    expect(s.session.matched, isEmpty);
    expect(s.session.isComplete, isFalse);
    s.session.dispose();
  });

  testWidgets('kata hijau menambah matched dan menaikkan akurasi', (
    tester,
  ) async {
    final s = _setup();
    s.engine.emitWord(_green(0, 'اا'));
    await tester.pump();

    expect(s.session.matched, {0});
    expect(s.session.accuracy, 1);
    expect(s.session.activeVerse, 0);
    s.session.dispose();
  });

  testWidgets('kata merah lalu dikoreksi: merah hilang, hijau tercatat', (
    tester,
  ) async {
    final s = _setup();
    s.engine.emitWord(_red(0));
    await tester.pump();

    expect(s.session.missed, {0});
    expect(s.session.matched, isEmpty);
    expect(s.session.accuracy, 0);
    expect(s.session.activeVerseMissed, isTrue);

    s.engine.emitWord(_green(0, 'اا'));
    await tester.pump();

    expect(s.session.missed, isEmpty);
    expect(s.session.matched, {0});
    expect(s.session.accuracy, 1);
    expect(s.session.activeVerseMissed, isFalse);
    s.session.dispose();
  });

  testWidgets('kata hijau yang hurufnya berbeda dihitung salah', (
    tester,
  ) async {
    final s = _setup();
    // 'بب' seharusnya, 'تت' yang terdengar — kerangka konsonan berbeda.
    s.engine.emitWord(_green(1, 'تت'));
    await tester.pump();

    expect(s.session.missed, {1});
    expect(s.session.matched, isEmpty);
    s.session.dispose();
  });

  testWidgets('intip: peekCount naik dan peekWord hilang setelah 2 detik', (
    tester,
  ) async {
    final s = _setup();
    s.session.peek();
    await tester.pump();

    expect(s.session.peekCount, 1);
    expect(s.session.peekWord, 0);

    await tester.pump(const Duration(seconds: 2));
    expect(s.session.peekWord, isNull);
    expect(s.session.peekCount, 1);
    s.session.dispose();
  });

  testWidgets('intip tidak menambah akurasi maupun kata benar', (tester) async {
    final s = _setup();
    s.session.peek();
    await tester.pump();

    expect(s.session.matched, isEmpty);
    expect(s.session.accuracy, 1);
    s.session.dispose();
  });

  testWidgets('rewind ayat aktif: rewindTo dipanggil, merah ayat lain tetap', (
    tester,
  ) async {
    final s = _setup();
    s.engine.emitWord(_red(0));
    s.engine.emitWord(_red(2));
    await tester.pump();

    expect(s.session.activeVerse, 1);
    expect(s.session.missed, {0, 2});

    s.session.retryCurrentVerse();
    await tester.pump();

    expect(s.engine.rewindCalls.last, 2);
    expect(s.session.missed, {0});
    s.session.dispose();
  });

  testWidgets('offset transkrip: kata ayat kedua tidak memakai bunyi ayat satu', (
    tester,
  ) async {
    final s = _setup();
    // Transkrip kumulatif satu segmen: bunyi ayat 1 lalu ayat 2.
    s.engine.emitTranscript('ااببججدد');
    await tester.pump();

    s.engine.emitWord(_red(2));
    await tester.pump();

    expect(s.session.activeVerse, 1);
    // Slot kata pertama ayat 2 hanya berisi bunyi ayat 2.
    expect(s.session.heardOf(2), 'جج');
    s.session.dispose();
  });

  testWidgets('surah selesai menghentikan listening', (tester) async {
    final s = _setup();
    s.engine.emitWord(_green(0, 'اا'));
    s.engine.emitWord(_green(1, 'بب'));
    s.engine.emitWord(_green(2, 'جج'));
    await tester.pump();
    expect(s.engine.stopCalls, 0);

    s.engine.emitWord(_green(3, 'دد'));
    await tester.pump();

    expect(s.session.isComplete, isTrue);
    expect(s.engine.stopCalls, 1);
    s.session.dispose();
  });

  testWidgets('resetAll mengosongkan state dan rewind ke kata 0', (
    tester,
  ) async {
    final s = _setup();
    s.engine.emitWord(_green(0, 'اا'));
    s.engine.emitWord(_red(2));
    s.session.peek();
    await tester.pump();
    expect(s.session.peekCount, 1);

    s.session.resetAll();
    await tester.pump();

    expect(s.engine.rewindCalls.last, 0);
    expect(s.session.matched, isEmpty);
    expect(s.session.missed, isEmpty);
    expect(s.session.activeVerse, 0);
    expect(s.session.peekWord, isNull);
    expect(s.session.peekCount, 0);
    s.session.dispose();
  });

  testWidgets('dispose saat sesi berjalan mengabaikan event berikutnya', (
    tester,
  ) async {
    final s = _setup();
    s.engine.emitWord(_green(0, 'اا'));
    s.session.peek();
    await tester.pump();
    expect(s.session.matched, {0});

    s.session.dispose();
    s.engine.emitWord(_green(1, 'بب'));
    await tester.pump(const Duration(seconds: 3));

    // Tidak ada perubahan state dan tidak ada exception dari timer.
    expect(s.session.matched, {0});
  });
}
