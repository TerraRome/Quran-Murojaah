import 'package:flutter/material.dart';
import 'package:quran/Quran/application/quran_controller.dart';
import 'package:quran/Quran/data/last_read_store.dart';
import 'package:quran/Quran/domain/entities/surah.dart';
import 'package:quran/Quran/domain/entities/verse.dart';
import 'package:quran/Quran/domain/failures/quran_failure.dart';
import 'package:quran/Quran/domain/repositories/quran_repository.dart';
import 'package:quran/Quran/murojaah/application/murojaah_session_state.dart';
import 'package:quran/Quran/murojaah/application/recitation_session_event.dart';
import 'package:quran/Quran/murojaah/application/verse_speaker.dart';
import 'package:quran/Quran/murojaah/domain/murojaah_match_result.dart';
import 'package:quran/Quran/murojaah/presentation/pages/mushaf_renderer_page.dart';
import 'package:quran/Quran/murojaah/presentation/widgets/murojaah_mushaf.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_murojaah_recitation_session.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeQuranRepository implements QuranRepository {
  _FakeQuranRepository(this.surahs);
  final List<Surah> surahs;

  @override
  Future<Either<QuranFailure, List<Surah>>> getSurahs() async => Right(surahs);

  @override
  Future<Either<QuranFailure, Surah>> getSurah(int number) async =>
      Right(surahs.firstWhere((s) => s.number == number));
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
  Future<void> stop() async => stopCount++;

  void finish() => _onDone?.call();

  @override
  void dispose() {}
}

// ---------------------------------------------------------------------------
// Fixture data
// ---------------------------------------------------------------------------

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

// Arabic with >15 words so isLongVerse == true.
String _longVerseArabic() =>
    'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ الْحَمْدُ لِلَّهِ رَبِّ '
    'الْعَالَمِينَ الرَّحْمَٰنِ الرَّحِيمِ مَالِكِ يَوْمِ الدِّينِ '
    'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ';

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

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Helpers ────────────────────────────────────────────────────────────────

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

  // ── E7: Basic rendering ────────────────────────────────────────────────────

  testWidgets('initial state shows Mulai Murojaah button', (tester) async {
    await pumpPage(tester);

    expect(find.text('Mulai Murojaah'), findsOneWidget);
    expect(find.text('Al-Ikhlas'), findsOneWidget);
    expect(find.byType(MurojaahMushaf), findsOneWidget);
    // E7: progress widgets removed
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.text('0 / 4'), findsNothing);
    // E7: Bicara/Berhenti buttons removed
    expect(find.text('Bicara'), findsNothing);
    expect(find.text('Berhenti'), findsNothing);
    // E7: no progress text hint
    expect(find.textContaining('Semua ayat'), findsNothing);
  });

  testWidgets('running phase shows mic + Ulang + Dengar', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Mulai Murojaah'));
    await tester.pumpAndSettle();

    expect(find.text('Ulang'), findsOneWidget);
    expect(find.text('Dengar'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none), findsOneWidget);
    // E7: old-style buttons gone
    expect(find.text('Bicara'), findsNothing);
    expect(find.text('Berhenti'), findsNothing);
    // E7: no progress text
    expect(find.text('Ayat 1 / 4'), findsNothing);
    expect(find.text('0 / 4'), findsNothing);
  });

  testWidgets('progress bar removed (E7)', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Mulai Murojaah'));
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('Selesai not shown for short verses (E7)', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Mulai Murojaah'));
    await tester.pumpAndSettle();

    expect(find.text('Selesai'), findsNothing);
    expect(find.text('Selesai rekam'), findsNothing);
  });

  testWidgets('completion state shows Murojaah selesai + Ulangi (E7)',
      (tester) async {
    final r = await pumpPage(tester);

    await tester.tap(find.text('Mulai Murojaah'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      await reciteCorrect(tester, r.session);
    }

    expect(find.text('Murojaah selesai'), findsOneWidget);
    expect(find.text('Ulangi'), findsOneWidget);
    // E7: old completion labels gone
    expect(find.text('Selesai'), findsNothing);
    expect(find.text('Mulai Ulang'), findsNothing);
    expect(find.text('Ayat 4 / 4'), findsNothing);
    expect(find.text('4 / 4'), findsNothing);
  });

  // ── Auto-scroll ────────────────────────────────────────────────────────────

  testWidgets('auto-scroll follows active verse then resets on Ulang',
      (tester) async {
    final r = await pumpPage(tester, surah: _longSurah());

    await tester.tap(find.text('Mulai Murojaah'));
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(MurojaahMushaf),
      matching: find.byType(Scrollable),
    );
    expect(
        tester.state<ScrollableState>(scrollable).position.pixels, lessThan(20));

    for (var i = 0; i < 12; i++) {
      r.session.simulateMatchingCompleted(
        matchResult: _acceptResult(),
        transcript: 'إنا أنزلناه في ليلة مباركة',
      );
      await tester.pumpAndSettle();
    }
    expect(tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(50));

    await tester.tap(find.text('Ulang'));
    await tester.pumpAndSettle();
    expect(
        tester.state<ScrollableState>(scrollable).position.pixels, lessThan(20));
    // Do NOT call r.session.dispose() here — the widget's own dispose() calls
    // session.stop() which closes the stream; a second dispose() would throw
    // "Bad state: Cannot add new events after calling close".
  });

  // ── MurojaahRecitationSession integration ─────────────────────────────────

  group('session integration', () {
    late FakeMurojaahRecitationSession session;
    late _FakeVerseSpeaker speaker;

    Future<void> pump(WidgetTester tester, {Surah? surah}) async {
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

    testWidgets('Mulai Murojaah calls session.start()', (tester) async {
      await pump(tester);

      expect(session.startCallCount, 0);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      expect(session.startCallCount, greaterThan(0));
      expect(session.lastStartConfig, isNotNull);
      expect(session.lastStartConfig!.expectedArabic, 'قُلْ هُوَ اللهُ أَحَدٌ');
    });

    testWidgets('listening state shows filled mic icon', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateState(
        const MurojaahSessionState(status: MurojaahSessionStatus.listening),
      );
      await tester.pump();

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsNothing);
    });

    testWidgets('ACCEPT advances verse, Ulang still present', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateMatchingCompleted(
        matchResult: _acceptResult(),
        transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
      );
      await tester.pumpAndSettle();

      // E7: no progress counter — just running state confirmed by button presence
      expect(find.text('Mulai Murojaah'), findsNothing);
      expect(find.text('Ulang'), findsOneWidget);
    });

    testWidgets('ACCEPT shows Benar! feedback briefly', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateMatchingCompleted(
        matchResult: _acceptResult(),
        transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
      );
      await tester.pump(); // capture momentary feedback before settle

      expect(find.text('Benar!'), findsOneWidget);
    });

    testWidgets('REJECT shows Belum tepat. feedback', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateMatchingCompleted(
        matchResult: _rejectResult(),
        transcript: 'wrong',
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum tepat.'), findsOneWidget);
      expect(find.text('Ulang'), findsOneWidget);
    });

    testWidgets('REJECT does not advance to completion', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateMatchingCompleted(
        matchResult: _rejectResult(),
        transcript: 'wrong',
      );
      await tester.pumpAndSettle();

      expect(find.text('Murojaah selesai'), findsNothing);
      expect(find.text('Ulang'), findsOneWidget);
    });

    testWidgets('all verses correct → Murojaah selesai', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      for (var i = 0; i < 4; i++) {
        session.simulateMatchingCompleted(
          matchResult: _acceptResult(),
          transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
        );
        await tester.pumpAndSettle();
      }

      expect(find.text('Murojaah selesai'), findsOneWidget);
      expect(find.text('Ulangi'), findsOneWidget);
    });

    testWidgets('Ulang restarts session from verse 1', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateMatchingCompleted(
        matchResult: _acceptResult(),
        transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
      );
      await tester.pumpAndSettle();

      final startsBefore = session.startCallCount;
      await tester.tap(find.text('Ulang'));
      await tester.pumpAndSettle();

      expect(session.startCallCount, greaterThan(startsBefore));
      expect(find.text('Ulang'), findsOneWidget);
    });

    testWidgets('processing status shows Memproses rekaman…', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateState(
        const MurojaahSessionState(status: MurojaahSessionStatus.processing),
      );
      await tester.pump(); // pumpAndSettle would time out if mic animates

      expect(find.text('Memproses…'), findsOneWidget);
    });

    testWidgets('permissionDenied shows Izin mikrofon ditolak.', (tester) async {
      await pump(tester);
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

    testWidgets('SessionError shows Terjadi kesalahan. Coba lagi.',
        (tester) async {
      await pump(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateState(
        const MurojaahSessionState(
          status: MurojaahSessionStatus.error,
          errorMessage: 'Recorder crashed',
        ),
      );
      session.simulateEvent(const SessionError(message: 'Recorder crashed'));
      await tester.pumpAndSettle();

      expect(find.text('Terjadi kesalahan. Coba lagi.'), findsOneWidget);
    });

    testWidgets('three REJECT events trigger TTS help', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      for (var i = 0; i < 2; i++) {
        session.simulateMatchingCompleted(
            matchResult: _rejectResult(), transcript: 'wrong');
        await tester.pumpAndSettle();
      }
      expect(speaker.spoken, isEmpty);

      session.simulateMatchingCompleted(
          matchResult: _rejectResult(), transcript: 'wrong');
      await tester.pumpAndSettle();

      expect(speaker.spoken, isNotEmpty);
      expect(find.text('Membacakan bacaan yang benar…'), findsOneWidget);
    });

    testWidgets('TTS speaking stops the recitation session', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      final stopsBefore = session.stopCallCount;

      for (var i = 0; i < 3; i++) {
        session.simulateMatchingCompleted(
            matchResult: _rejectResult(), transcript: 'wrong');
        await tester.pumpAndSettle();
      }

      expect(session.stopCallCount, greaterThan(stopsBefore));
    });

    testWidgets('page disposal stops the recitation session', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      final stopsBefore = session.stopCallCount;

      await tester.pumpWidget(
        const QuranThemeScope(child: MaterialApp(home: SizedBox())),
      );
      await tester.pumpAndSettle();

      expect(session.stopCallCount, greaterThan(stopsBefore));
    });
  });

  // ── E6: Continuous listening ───────────────────────────────────────────────

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

    testWidgets('Mulai Murojaah auto-starts session (E6)', (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      expect(session.startCallCount, greaterThan(0));
      // E7: no Bicara button needed — session already started
      expect(find.text('Bicara'), findsNothing);
    });

    testWidgets('listening state shows filled mic (E6)', (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateState(
        const MurojaahSessionState(status: MurojaahSessionStatus.listening),
      );
      await tester.pump();

      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('ACCEPT auto-restarts session for next verse (E6)',
        (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      final startBefore = session.startCallCount;
      session.simulateMatchingCompleted(
        matchResult: _acceptResult(),
        transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
      );
      session.simulateEvent(const SessionStopped());
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(session.startCallCount, greaterThan(startBefore));
    });

    testWidgets('REJECT keeps same verse, mic still available (E6)',
        (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateMatchingCompleted(
          matchResult: _rejectResult(), transcript: 'wrong');
      await tester.pumpAndSettle();

      expect(find.text('Ulang'), findsOneWidget);
      expect(find.text('Belum tepat.'), findsOneWidget);
      expect(find.text('Murojaah selesai'), findsNothing);
    });

    testWidgets('Selesai rekam hidden when no accumulated transcript (E6)',
        (tester) async {
      final longSurah = Surah(
        number: 1,
        name: 'الفاتحة',
        transliteration: 'Al-Fatihah',
        translation: 'Pembukaan',
        revelationType: RevelationType.meccan,
        totalVerses: 1,
        verses: [
          Verse(
            number: 1001,
            numberInSurah: 1,
            arabic: _longVerseArabic(),
            translation: 'Test verse with many words',
          ),
        ],
      );

      await pumpE6(tester, surah: longSurah);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      expect(find.text('Selesai rekam'), findsNothing);
    });

    testWidgets('Selesai hidden for short verses (E6/E7)', (tester) async {
      await pumpE6(tester); // _surahIkhlas has 4-word verses → short
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      expect(find.text('Selesai'), findsNothing);
    });

    testWidgets('completion: no progress bar, no Ayat X/Y (E6/E7)',
        (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      for (var i = 0; i < 4; i++) {
        session.simulateMatchingCompleted(
          matchResult: _acceptResult(),
          transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
        );
        await tester.pumpAndSettle();
      }

      expect(find.text('Murojaah selesai'), findsOneWidget);
      expect(find.text('Ulangi'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Ayat 4 / 4'), findsNothing);
    });

    testWidgets('all 4 verses accepted → no more auto-starts (E6)',
        (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

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

      final startsBefore = session.startCallCount;
      session.simulateMatchingCompleted(
        matchResult: _acceptResult(),
        transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
      );
      await tester.pump();
      session.simulateEvent(const SessionStopped());
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Phase completed — no further starts.
      expect(session.startCallCount, startsBefore);
      expect(find.text('Murojaah selesai'), findsOneWidget);
    });

    testWidgets('auto-restart deferred when TTS is speaking (E6)',
        (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      final startsBefore = session.startCallCount;

      // REJECT×3 → TTS fires
      for (var i = 0; i < 3; i++) {
        session.simulateMatchingCompleted(
            matchResult: _rejectResult(), transcript: 'wrong');
        await tester.pumpAndSettle();
      }
      expect(speaker.spoken, isNotEmpty);

      // Session stopped while TTS is active
      session.simulateEvent(const SessionStopped());
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      // Auto-restart should be suppressed while TTS is speaking
      expect(session.startCallCount, startsBefore);
    });

    testWidgets('auto-restart fires after TTS finishes (E6)', (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      // REJECT×3 → TTS help fires, session stops
      for (var i = 0; i < 3; i++) {
        session.simulateMatchingCompleted(
            matchResult: _rejectResult(), transcript: 'wrong');
        await tester.pumpAndSettle();
      }
      // TTS is now speaking — confirmed by speaker.spoken being non-empty.
      expect(speaker.spoken, isNotEmpty);

      // ACCEPT while TTS is still speaking sets _pendingAutoAdvance = true.
      // Then SessionStopped fires — page sees TTS is speaking → defers restart.
      session.simulateMatchingCompleted(
          matchResult: _acceptResult(), transcript: 'قُلْ هُوَ اللهُ أَحَدٌ');
      await tester.pumpAndSettle();
      session.simulateEvent(const SessionStopped());
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      final startsBefore = session.startCallCount;
      // TTS finishes → _onSpeakerChanged fires → deferred restart executes.
      speaker.finish();
      await tester.pumpAndSettle();

      expect(session.startCallCount, greaterThan(startsBefore));
    });

    testWidgets('Ulangi from completion state restarts (E6)', (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      for (var i = 0; i < 4; i++) {
        session.simulateMatchingCompleted(
          matchResult: _acceptResult(),
          transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('Murojaah selesai'), findsOneWidget);

      final startsBefore = session.startCallCount;
      await tester.tap(find.text('Ulangi'));
      await tester.pumpAndSettle();

      expect(session.startCallCount, greaterThan(startsBefore));
      expect(find.text('Ulang'), findsOneWidget);
      expect(find.text('Murojaah selesai'), findsNothing);
    });

    testWidgets('dispose during pending auto-advance timer does not crash',
        (tester) async {
      await pumpE6(tester);
      await tester.tap(find.text('Mulai Murojaah'));
      await tester.pumpAndSettle();

      session.simulateMatchingCompleted(
        matchResult: _acceptResult(),
        transcript: 'قُلْ هُوَ اللهُ أَحَدٌ',
      );
      await tester.pump();
      session.simulateEvent(const SessionStopped());
      await tester.pump(); // timer armed, not yet fired

      // Replace tree — disposes MushafRendererPage mid-timer.
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      // Advance past the timer — should not throw.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      // No exception = pass.
    });
  });
}
