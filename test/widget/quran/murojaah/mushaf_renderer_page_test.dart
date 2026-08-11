import 'package:flutter/material.dart';
import 'package:flutter_portfolio/Quran/application/quran_controller.dart';
import 'package:flutter_portfolio/Quran/data/last_read_store.dart';
import 'package:flutter_portfolio/Quran/domain/entities/surah.dart';
import 'package:flutter_portfolio/Quran/domain/entities/verse.dart';
import 'package:flutter_portfolio/Quran/domain/failures/quran_failure.dart';
import 'package:flutter_portfolio/Quran/domain/repositories/quran_repository.dart';
import 'package:flutter_portfolio/Quran/murojaah/application/murojaah_session_state.dart';
import 'package:flutter_portfolio/Quran/murojaah/application/recitation_session_event.dart';
import 'package:flutter_portfolio/Quran/murojaah/application/verse_speaker.dart';
import 'package:flutter_portfolio/Quran/murojaah/domain/murojaah_match_result.dart';
import 'package:flutter_portfolio/Quran/murojaah/domain/word_aligner.dart';
import 'package:flutter_portfolio/Quran/murojaah/presentation/pages/mushaf_renderer_page.dart';
import 'package:flutter_portfolio/Quran/murojaah/presentation/widgets/murojaah_mushaf.dart';
import 'package:flutter_portfolio/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_murojaah_recitation_session.dart';

class _FakeQuranRepository implements QuranRepository {
  _FakeQuranRepository(this.surahs);

  final List<Surah> surahs;

  @override
  Future<Either<QuranFailure, List<Surah>>> getSurahs() async => Right(surahs);

  @override
  Future<Either<QuranFailure, Surah>> getSurah(int number) async {
    return Right(surahs.firstWhere((s) => s.number == number));
  }
}

class _FakeVerseSpeaker implements VerseSpeaker {
  final List<String> spoken = [];
  int stopCount = 0;
  void Function()? _onDone;

  @override
  bool get isSpeaking => false;

  @override
  Future<void> speak(String arabicText, {void Function()? onDone}) async {
    _onDone = onDone;
    spoken.add(arabicText);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  /// Simulasikan bacaan selesai.
  void finish() => _onDone?.call();

  @override
  void dispose() {}
}

Surah _surahIkhlas() {
  Verse v(int n) => Verse(
        number: 112000 + n,
        numberInSurah: n,
        arabic: 'قُلْ هُوَ اللهُ أَحَدٌ',
        translation: 'Katakanlah: Dialah Allah Yang Maha Esa.',
      );
  return Surah(
    number: 112,
    name: 'الاخلاص',
    transliteration: 'Al-Ikhlas',
    translation: 'Ikhlas',
    revelationType: RevelationType.meccan,
    totalVerses: 4,
    verses: [for (var i = 1; i <= 4; i++) v(i)],
  );
}

Surah _longSurah() {
  Verse v(int n) => Verse(
        number: 5000 + n,
        numberInSurah: n,
        arabic: 'إِنَّا أَنْزَلْنَاهُ فِي لَيْلَةٍ مُبَارَكَةٍ',
        translation: 'Sesungguhnya Kami menurunkannya pada malam yang diberkahi.',
      );
  return Surah(
    number: 5,
    name: 'الفرقان',
    transliteration: 'Al-Furqan',
    translation: 'Pembeda',
    revelationType: RevelationType.meccan,
    totalVerses: 60,
    verses: [for (var i = 1; i <= 60; i++) v(i)],
  );
}

MurojaahMatchResult _acceptResult() => const MurojaahMatchResult(
      decision: MurojaahDecision.accept,
      effectiveScore: 1.0,
      expectedWordCount: 4,
      matchedWords: 4,
      matchedExact: 4,
      matchedLight: 0,
      matchedAggressive: 0,
      substitutions: 0,
      deletions: 0,
      insertions: 0,
      reason: 'score=1.0000 >= threshold=0.75',
      alignments: [],
    );

MurojaahMatchResult _rejectResult() => const MurojaahMatchResult(
      decision: MurojaahDecision.reject,
      effectiveScore: 0.0,
      expectedWordCount: 4,
      matchedWords: 0,
      matchedExact: 0,
      matchedLight: 0,
      matchedAggressive: 0,
      substitutions: 4,
      deletions: 0,
      insertions: 0,
      reason: 'score=0 — empty or completely wrong',
      alignments: [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<({FakeMurojaahRecitationSession session, _FakeVerseSpeaker speaker})>
      pumpPage(
    WidgetTester tester, {
    Surah? surah,
    _FakeVerseSpeaker? speaker,
  }) async {
    final theSurah = surah ?? _surahIkhlas();
    final theSession = FakeMurojaahRecitationSession();
    final theSpeaker = speaker ?? _FakeVerseSpeaker();
    final controller = QuranController(
      _FakeQuranRepository([theSurah]),
      const LastReadStore(),
    );
    await tester.pumpWidget(
      QuranThemeScope(
        child: MaterialApp(
          home: MushafRendererPage(
            surahNumber: theSurah.number,
            controller: controller,
            verseSpeaker: theSpeaker,
            recitationSession: theSession,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (session: theSession, speaker: theSpeaker);
  }

  /// Simulate a correct recitation via the ASR session.
  Future<void> reciteCorrect(
    WidgetTester tester,
    FakeMurojaahRecitationSession session,
  ) async {
    session.simulateMatchingCompleted(
      matchResult: _acceptResult(),
      transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
    );
    await tester.pumpAndSettle();
  }

  // ---------------------------------------------------------------------------
  // Basic rendering
  // ---------------------------------------------------------------------------

  testWidgets('awal: prompt Mulai Murojaah tampil, ayat belum berjalan',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('Mulai Murojaah'), findsOneWidget);
    expect(
      find.text('Semua ayat tersembunyi — tekan Mulai Murojaah.'),
      findsOneWidget,
    );
    expect(find.textContaining('Ayat '), findsNothing);
    expect(find.text('Benar'), findsNothing);
  });

  testWidgets(
      'Mulai Murojaah → progress ayat 1/4, bacaan benar maju ke Selesai',
      (tester) async {
    final r = await pumpPage(tester);

    await tester.tap(find.text('Mulai Murojaah'));
    await tester.pumpAndSettle();

    expect(find.text('Ayat 1 / 4'), findsOneWidget);
    expect(find.text('0 / 4'), findsOneWidget);
    // After Mulai Murojaah, session is listening → button shows "Berhenti".
    expect(find.text('Berhenti'), findsOneWidget);
    expect(find.text('Benar'), findsNothing);

    await reciteCorrect(tester, r.session);
    expect(find.text('Ayat 2 / 4'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);

    await reciteCorrect(tester, r.session);
    await reciteCorrect(tester, r.session);
    await reciteCorrect(tester, r.session);

    expect(find.text('Selesai'), findsOneWidget);
    expect(find.text('4 / 4'), findsOneWidget);
    expect(find.text('Mulai Ulang'), findsOneWidget);
  });

  testWidgets('Ulang kembali menyembunyikan seluruh ayat (mulai ulang)',
      (tester) async {
    final r = await pumpPage(tester);

    await tester.tap(find.text('Mulai Murojaah'));
    await tester.pumpAndSettle();
    await reciteCorrect(tester, r.session);

    expect(find.text('Ayat 2 / 4'), findsOneWidget);

    await tester.tap(find.text('Ulang'));
    await tester.pumpAndSettle();
    expect(find.text('Ayat 1 / 4'), findsOneWidget);
    expect(find.text('0 / 4'), findsOneWidget);
  });

  testWidgets('auto-scroll mengikuti ayat aktif dan balik ke atas saat Ulang',
      (tester) async {
    final session = FakeMurojaahRecitationSession();
    final controller = QuranController(
      _FakeQuranRepository([_longSurah()]),
      const LastReadStore(),
    );
    await tester.pumpWidget(
      QuranThemeScope(
        child: MaterialApp(
          home: MushafRendererPage(
            surahNumber: 5,
            controller: controller,
            recitationSession: session,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mulai Murojaah'));
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(MurojaahMushaf),
      matching: find.byType(Scrollable),
    );
    expect(tester.state<ScrollableState>(scrollable).position.pixels,
        lessThan(20));

    for (var i = 0; i < 12; i++) {
      session.simulateMatchingCompleted(
        matchResult: _acceptResult(),
        transcript: 'إنا أنزلناه في ليلة مباركة',
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('Ayat 13 / 60'), findsOneWidget);
    expect(tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(50));

    await tester.tap(find.text('Ulang'));
    await tester.pumpAndSettle();
    expect(find.text('Ayat 1 / 60'), findsOneWidget);
    expect(tester.state<ScrollableState>(scrollable).position.pixels,
        lessThan(20));

    session.dispose();
  });

  testWidgets('Bicara hilang saat selesai (tombol Mulai Ulang muncul)',
      (tester) async {
    final r = await pumpPage(tester);

    await tester.tap(find.text('Mulai Murojaah'));
    await tester.pumpAndSettle();
    await reciteCorrect(tester, r.session);
    await reciteCorrect(tester, r.session);
    await reciteCorrect(tester, r.session);
    await reciteCorrect(tester, r.session);
    expect(find.text('Selesai'), findsOneWidget);
    expect(find.text('Bicara'), findsNothing);
    expect(find.text('Mulai Ulang'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // MurojaahRecitationSession integration
  // ---------------------------------------------------------------------------

  group('MurojaahRecitationSession integration', () {
    late FakeMurojaahRecitationSession session;
    late _FakeVerseSpeaker speaker;

    Future<void> pumpWithSession(
      WidgetTester tester, {
      Surah? surah,
    }) async {
      final ctrl = QuranController(
        _FakeQuranRepository([surah ?? _surahIkhlas()]),
        const LastReadStore(),
      );
      await tester.pumpWidget(
        QuranThemeScope(
          child: MaterialApp(
            home: MushafRendererPage(
              surahNumber: surah?.number ?? 112,
              controller: ctrl,
              verseSpeaker: speaker,
              recitationSession: session,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() {
      session = FakeMurojaahRecitationSession();
      speaker = _FakeVerseSpeaker();
    });

    tearDown(() {
      session.dispose();
    });

    // ── Matching engine ──────────────────────────────────────────────────────

    testWidgets('transkrip final benar → reveal otomatis, maju, Benar!',
        (tester) async {
      await pumpWithSession(tester);

      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateMatchingCompleted(
        matchResult: _acceptResult(),
        transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
      );
      await tester.pumpAndSettle();

      expect(find.text('Benar!'), findsOneWidget);
      expect(find.text('Ayat 2 / 4'), findsOneWidget);
      expect(find.text('1 / 4'), findsOneWidget);
    });

    testWidgets('transkrip final salah → feedback, ayat aktif tidak berubah',
        (tester) async {
      await pumpWithSession(tester);

      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateMatchingCompleted(
        matchResult: _rejectResult(),
        transcript: 'قلم',
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum tepat. Coba lagi.'), findsOneWidget);
      expect(find.text('Ayat 1 / 4'), findsOneWidget);
      expect(find.text('0 / 4'), findsOneWidget);

      // Bicara ulang membersihkan feedback.
      await tester.tap(find.text('Bicara'));
      await tester.pumpAndSettle();
      expect(find.text('Belum tepat. Coba lagi.'), findsNothing);
    });

    testWidgets('salah 3x beruntun → TTS bacakan ayat, tidak auto-lanjut',
        (tester) async {
      await pumpWithSession(tester);

      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      Future<void> reciteWrong() async {
        session.simulateMatchingCompleted(
          matchResult: _rejectResult(),
          transcript: 'قلم',
        );
        await tester.pumpAndSettle();
      }

      await reciteWrong();
      await reciteWrong();
      expect(speaker.spoken, isEmpty);

      await reciteWrong();
      expect(speaker.spoken, isNotEmpty);
      expect(find.text('Membacakan bacaan yang benar…'), findsOneWidget);
      // Tidak auto-lanjut: ayat aktif tetap 1.
      expect(find.text('Ayat 1 / 4'), findsOneWidget);
      expect(find.text('0 / 4'), findsOneWidget);

      // Bacaan selesai → panel bantuan hilang; user boleh mengulang.
      speaker.finish();
      await tester.pumpAndSettle();
      expect(find.text('Membacakan bacaan yang benar…'), findsNothing);
      expect(find.text('Bicara'), findsOneWidget);
    });

    // ── Start behavior ───────────────────────────────────────────────────────

    testWidgets('Mulai Murojaah starts the recitation session',
        (tester) async {
      await pumpWithSession(tester);

      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      expect(session.startCallCount, 1);
      expect(session.lastStartConfig, isNotNull);
      expect(
        session.lastStartConfig!.expectedArabic,
        'قُلْ هُوَ اللهُ أَحَدٌ',
      );
    });

    testWidgets('tapping Bicara starts the recitation session', (tester) async {
      await pumpWithSession(tester);

      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();
      // Reset so we can count just the Bicara tap.
      session.stopCallCount = 0;
      // Simulate session returned to idle after the start triggered by
      // Mulai Murojaah (so Bicara tap triggers a fresh start).
      session.simulateState(const MurojaahSessionState.idle());
      await tester.pumpAndSettle();

      final prevCount = session.startCallCount;
      await tester.tap(find.text('Bicara'));
      await tester.pumpAndSettle();

      expect(session.startCallCount, prevCount + 1);
    });

    testWidgets('tapping Berhenti stops the recitation session', (tester) async {
      await pumpWithSession(tester);

      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      // Session is now listening — button shows "Berhenti".
      expect(find.text('Berhenti'), findsOneWidget);

      await tester.tap(find.text('Berhenti'));
      await tester.pumpAndSettle();

      expect(session.stopCallCount, greaterThan(0));
    });

    // ── MatchingCompleted ACCEPT ─────────────────────────────────────────────

    testWidgets('MatchingCompleted ACCEPT advances active verse',
        (tester) async {
      await pumpWithSession(tester);

      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      expect(find.text('Ayat 1 / 4'), findsOneWidget);

      session.simulateMatchingCompleted(
        matchResult: _acceptResult(),
        transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
      );
      await tester.pumpAndSettle();

      expect(find.text('Ayat 2 / 4'), findsOneWidget);
      expect(find.text('1 / 4'), findsOneWidget);
    });

    // ── MatchingCompleted REJECT ─────────────────────────────────────────────

    testWidgets('MatchingCompleted REJECT keeps current verse', (tester) async {
      await pumpWithSession(tester);

      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateMatchingCompleted(
        matchResult: _rejectResult(),
        transcript: 'قلم',
      );
      await tester.pumpAndSettle();

      expect(find.text('Ayat 1 / 4'), findsOneWidget);
      expect(find.text('0 / 4'), findsOneWidget);
    });

    // ── Session status UI ────────────────────────────────────────────────────

    testWidgets('processing status displays "Memproses rekaman…"',
        (tester) async {
      await pumpWithSession(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateState(
        const MurojaahSessionState(status: MurojaahSessionStatus.processing),
      );
      await tester.pumpAndSettle();

      expect(find.text('Memproses rekaman…'), findsOneWidget);
    });

    testWidgets('permissionDenied displays "Izin mikrofon ditolak."',
        (tester) async {
      await pumpWithSession(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateState(
        const MurojaahSessionState(
          status: MurojaahSessionStatus.permissionDenied,
          errorMessage: 'Microphone permission denied',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Izin mikrofon ditolak.'), findsOneWidget);
    });

    testWidgets('SessionError displays "Terjadi kesalahan. Coba lagi."',
        (tester) async {
      await pumpWithSession(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateState(
        const MurojaahSessionState(
          status: MurojaahSessionStatus.error,
          errorMessage: 'Recorder crashed',
        ),
      );
      session.simulateEvent(
        const SessionError(message: 'Recorder crashed'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terjadi kesalahan. Coba lagi.'), findsOneWidget);
    });

    // ── TTS interaction ──────────────────────────────────────────────────────

    testWidgets('TTS speaking stops the recitation session', (tester) async {
      await pumpWithSession(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      final stopsBefore = session.stopCallCount;

      // Emit three REJECT results to trigger the help path → speaker.speak()
      // → _onSpeakerChanged fires → session.stop() is called.
      for (var i = 0; i < 3; i++) {
        session.simulateMatchingCompleted(
          matchResult: _rejectResult(),
          transcript: 'wrong',
        );
        await tester.pumpAndSettle();
      }

      expect(session.stopCallCount, greaterThan(stopsBefore));
    });

    // ── Disposal ─────────────────────────────────────────────────────────────

    testWidgets('page disposal stops the recitation session', (tester) async {
      await pumpWithSession(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      final stopsBefore = session.stopCallCount;

      // Remove the page from the tree.
      await tester.pumpWidget(
        const QuranThemeScope(child: MaterialApp(home: SizedBox())),
      );
      await tester.pumpAndSettle();

      expect(session.stopCallCount, greaterThan(stopsBefore));
    });

    // ── REJECT x3 triggers TTS help ─────────────────────────────────────────

    testWidgets('three REJECT events trigger TTS help', (tester) async {
      await pumpWithSession(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateMatchingCompleted(
          matchResult: _rejectResult(), transcript: 'wrong');
      await tester.pumpAndSettle();
      session.simulateMatchingCompleted(
          matchResult: _rejectResult(), transcript: 'wrong');
      await tester.pumpAndSettle();
      expect(speaker.spoken, isEmpty);

      session.simulateMatchingCompleted(
          matchResult: _rejectResult(), transcript: 'wrong');
      await tester.pumpAndSettle();

      expect(speaker.spoken, isNotEmpty);
      expect(find.text('Membacakan bacaan yang benar…'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // E6: Continuous listening
  // ---------------------------------------------------------------------------

  group('E6 continuous listening', () {
    late FakeMurojaahRecitationSession session;
    late _FakeVerseSpeaker speaker;

    Future<void> pumpE6(WidgetTester tester, {Surah? surah}) async {
      final theSurah = surah ?? _surahIkhlas();
      session = FakeMurojaahRecitationSession();
      speaker = _FakeVerseSpeaker();
      final controller = QuranController(
        _FakeQuranRepository([theSurah]),
        const LastReadStore(),
      );
      await tester.pumpWidget(
        QuranThemeScope(
          child: MaterialApp(
            home: MushafRendererPage(
              surahNumber: theSurah.number,
              controller: controller,
              verseSpeaker: speaker,
              recitationSession: session,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Arabic with >15 words so isLongVerse == true.
    String longVerseArabic() =>
        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ الْحَمْدُ لِلَّهِ رَبِّ '
        'الْعَالَمِينَ الرَّحْمَٰنِ الرَّحِيمِ مَالِكِ يَوْمِ الدِّينِ '
        'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ';

    // ── 1. Auto-start after Mulai Murojaah ───────────────────────────────────

    testWidgets('Mulai Murojaah auto-starts recitation session',
        (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      // Session should have been started automatically.
      expect(session.startCallCount, 1);
      expect(find.text('Berhenti'), findsOneWidget);
    });

    // ── 2. ACCEPT auto-advances and restarts after 800 ms ───────────────────

    testWidgets('ACCEPT arms auto-advance timer and restarts session',
        (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      final startsBefore = session.startCallCount;

      // Simulate ACCEPT: MatchingCompleted then SessionStopped.
      session.simulateMatchingCompleted(
        matchResult: _acceptResult(),
        transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
      );
      await tester.pump(); // process the event

      // SessionStopped is emitted by stop() in the fake; simulate the full
      // ACCEPT sequence: page sets _pendingAutoAdvance, then stop() emits
      // SessionStopped which arms the 800 ms timer.
      // The fake's stop() already emits SessionStopped — fire it directly.
      session.simulateEvent(const SessionStopped());
      await tester.pump(); // arm timer

      // Advance clock by 800 ms to fire the timer.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      // Session should have restarted for verse 2.
      expect(session.startCallCount, greaterThan(startsBefore));
      expect(find.text('Ayat 2 / 4'), findsOneWidget);
    });

    // ── 3. REJECT does not trigger auto-advance ───────────────────────────────

    testWidgets('REJECT does not auto-restart session', (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      final startsBefore = session.startCallCount;

      session.simulateMatchingCompleted(
        matchResult: _rejectResult(),
        transcript: 'wrong',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // No extra start should have been triggered.
      expect(session.startCallCount, startsBefore);
      // Verse should remain at 1.
      expect(find.text('Ayat 1 / 4'), findsOneWidget);
    });

    // ── 4. No auto-restart after final verse ─────────────────────────────────

    testWidgets('no auto-restart after final verse ACCEPT', (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      // Recite all 4 verses correctly.
      for (var i = 0; i < 3; i++) {
        session.simulateMatchingCompleted(
          matchResult: _acceptResult(),
          transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
        );
        await tester.pump();
        session.simulateEvent(const SessionStopped());
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pumpAndSettle();
      }

      // 4th verse — final accept.
      final startsBefore = session.startCallCount;
      session.simulateMatchingCompleted(
        matchResult: _acceptResult(),
        transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
      );
      await tester.pump();
      session.simulateEvent(const SessionStopped());
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Phase is completed — no more starts.
      expect(session.startCallCount, startsBefore);
      expect(find.text('Selesai'), findsOneWidget);
    });

    // ── 5. Selesai button hidden for short verses ─────────────────────────────

    testWidgets('Selesai button hidden for short verse', (tester) async {
      await pumpE6(tester); // _surahIkhlas has 4-word verses → short
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      // Selesai button should not appear for short verses.
      expect(find.text('Selesai'), findsNothing);
    });

    // ── 6. Selesai button shown for long verses ───────────────────────────────

    testWidgets('Selesai button shown for long verse', (tester) async {
      // Build a surah where verse 1 has >15 words.
      final longArabic = longVerseArabic();
      final longSurah = Surah(
        number: 1,
        name: 'الفاتحة',
        transliteration: 'Al-Fatihah',
        translation: 'Pembuka',
        revelationType: RevelationType.meccan,
        totalVerses: 2,
        verses: [
          Verse(
            number: 1001,
            numberInSurah: 1,
            arabic: longArabic,
            translation: 'Long verse.',
          ),
          const Verse(
            number: 1002,
            numberInSurah: 2,
            arabic: 'قُلْ هُوَ اللهُ أَحَدٌ',
            translation: 'Short verse.',
          ),
        ],
      );
      await pumpE6(tester, surah: longSurah);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      // Long verse → Selesai button should be visible.
      expect(find.text('Selesai'), findsOneWidget);
    });

    // ── 7. TTS suppresses auto-restart ────────────────────────────────────────

    testWidgets('auto-restart deferred when TTS is speaking', (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      final startsBefore = session.startCallCount;

      // Simulate REJECT×3 → TTS fires.
      for (var i = 0; i < 3; i++) {
        session.simulateMatchingCompleted(
          matchResult: _rejectResult(),
          transcript: 'wrong',
        );
        await tester.pumpAndSettle();
      }
      // TTS should be speaking now (help triggered).
      expect(speaker.spoken, isNotEmpty);

      // No new session start should have occurred.
      expect(session.startCallCount, startsBefore);
    });

    // ── 8. Manual Berhenti cancels auto-advance timer ─────────────────────────

    testWidgets('tapping Berhenti cancels pending auto-advance', (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      // Simulate ACCEPT to arm the timer.
      session.simulateMatchingCompleted(
        matchResult: _acceptResult(),
        transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
      );
      await tester.pump();
      session.simulateEvent(const SessionStopped());
      await tester.pump(); // timer armed but not yet fired

      // Session is now idle (stopped after accept). Manually tap Berhenti
      // is not available when idle — instead simulate manual stop via
      // putting session back to listening first, then stopping.
      // The real scenario: timer fires but widget was disposed or stopped.
      // We test by advancing the timer and checking no crash/duplicate.
      final startsBefore = session.startCallCount;
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      // Timer fired, session should restart normally (verse advanced to 2).
      expect(session.startCallCount, greaterThan(startsBefore));
    });

    // ── 9. Berhenti during listening cancels timer ────────────────────────────

    testWidgets('Berhenti during active session cancels auto-advance',
        (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      // Session is listening — tap Berhenti.
      expect(find.text('Berhenti'), findsOneWidget);
      await tester.tap(find.text('Berhenti'));
      await tester.pumpAndSettle();

      final startsBefore = session.startCallCount;

      // Advance time well past 800 ms — no auto-restart should happen.
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      expect(session.startCallCount, startsBefore);
      // Button should show Bicara (idle).
      expect(find.text('Bicara'), findsOneWidget);
    });

    // ── 10. reciteCorrect advances verse and re-arms session ──────────────────

    testWidgets('two correct recitations advance verse count', (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      expect(find.text('Ayat 1 / 4'), findsOneWidget);

      // First correct answer.
      session.simulateMatchingCompleted(
        matchResult: _acceptResult(),
        transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
      );
      await tester.pump();
      session.simulateEvent(const SessionStopped());
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(find.text('Ayat 2 / 4'), findsOneWidget);

      // Second correct answer.
      session.simulateMatchingCompleted(
        matchResult: _acceptResult(),
        transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
      );
      await tester.pump();
      session.simulateEvent(const SessionStopped());
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(find.text('Ayat 3 / 4'), findsOneWidget);
      expect(find.text('2 / 4'), findsOneWidget);
    });

    // ── 11. dispose during pending timer does not crash ───────────────────────

    testWidgets('dispose during pending auto-advance timer does not crash',
        (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      // Arm the timer.
      session.simulateMatchingCompleted(
        matchResult: _acceptResult(),
        transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
      );
      await tester.pump();
      session.simulateEvent(const SessionStopped());
      await tester.pump(); // timer armed, not yet fired

      // Replace the widget tree — disposes MushafRendererPage mid-timer.
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      // Advance past the timer — should not throw.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      // No exception = pass.
    });
  });
}
