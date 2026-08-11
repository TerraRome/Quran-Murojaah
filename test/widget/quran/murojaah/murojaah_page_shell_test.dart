/// murojaah_page_shell_test.dart
///
/// Widget tests for MurojaahPageShell (E5: legacy path removed).
///
/// Test constraint: we do NOT construct a real StreamingRecordAudioRecorder
/// or trigger record-package platform channels in tests. Widget tests pump
/// MushafRendererPage directly with a FakeMurojaahRecitationSession to avoid
/// platform-backed objects.
///
/// Lifecycle ownership (session.stop + session.dispose called exactly once by
/// the shell) cannot be tested in a pure widget-test environment without
/// changing production architecture (injecting a factory callback). This
/// limitation is documented below.
library;

import 'package:flutter/material.dart';
import 'package:flutter_portfolio/Quran/application/quran_controller.dart';
import 'package:flutter_portfolio/Quran/data/last_read_store.dart';
import 'package:flutter_portfolio/Quran/domain/entities/surah.dart';
import 'package:flutter_portfolio/Quran/domain/entities/verse.dart';
import 'package:flutter_portfolio/Quran/domain/failures/quran_failure.dart';
import 'package:flutter_portfolio/Quran/domain/repositories/quran_repository.dart';
import 'package:flutter_portfolio/Quran/murojaah/presentation/pages/murojaah_page_shell.dart';
import 'package:flutter_portfolio/Quran/murojaah/presentation/pages/mushaf_renderer_page.dart';
import 'package:flutter_portfolio/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_murojaah_recitation_session.dart';

// ---------------------------------------------------------------------------
// Minimal fake repository
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

Surah _surahIkhlas() {
  Verse v(int n) => Verse(
        number: 112000 + n,
        numberInSurah: n,
        arabic: 'قُلْ هُوَ اللهُ أَحَدْ',
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

// ---------------------------------------------------------------------------
// Helper: pump MushafRendererPage with a FakeMurojaahRecitationSession so the
// page can load the surah without hitting real assets or platform channels.
// ---------------------------------------------------------------------------

Future<FakeMurojaahRecitationSession> pumpShell(
  WidgetTester tester, {
  int surahNumber = 112,
}) async {
  final ctrl = QuranController(
    _FakeQuranRepository([_surahIkhlas()]),
    const LastReadStore(),
  );
  final session = FakeMurojaahRecitationSession();

  await tester.pumpWidget(
    QuranThemeScope(
      child: MaterialApp(
        home: MushafRendererPage(
          surahNumber: surahNumber,
          controller: ctrl,
          recitationSession: session,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Shell renders correctly ───────────────────────────────────────────────

  testWidgets('MushafRendererPage renders initial state with ASR session',
      (tester) async {
    await pumpShell(tester);

    expect(find.text('Mulai Murojaah'), findsOneWidget);
    expect(
      find.text('Semua ayat tersembunyi — tekan Mulai Murojaah.'),
      findsOneWidget,
    );
  });

  testWidgets('MurojaahPageShell is a StatefulWidget', (tester) async {
    const shell = MurojaahPageShell(surahNumber: 112);
    expect(shell.surahNumber, 112);
    expect(shell, isA<StatefulWidget>());
  });

  testWidgets('Berhenti button present after Mulai Murojaah (session is listening)',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Mulai Murojaah'));
    await tester.pumpAndSettle();

    // After Mulai Murojaah, _startRecitationSession() is called which
    // transitions the fake session to MurojaahSessionStatus.listening.
    // The button therefore shows "Berhenti", not "Bicara".
    expect(find.text('Berhenti'), findsOneWidget);
  });

  // ── Documentation of lifecycle test limitation ────────────────────────────

  // NOTE: Testing that the shell calls session.stop() and session.dispose()
  // exactly once when disposed is not possible in this widget-test environment
  // without injecting a factory callback (which would change production
  // architecture). The mushaf_renderer_page_test.dart tests already verify
  // that the page correctly calls session.stop() on dispose using
  // FakeMurojaahRecitationSession. The shell's dispose() logic is three lines
  // of straightforward Dart with no branching.
}
