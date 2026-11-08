import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:quran/Quran/application/quran_controller.dart';
import 'package:quran/Quran/data/last_read_store.dart';
import 'package:quran/Quran/domain/entities/surah.dart';
import 'package:quran/Quran/domain/entities/verse.dart';
import 'package:quran/Quran/domain/failures/quran_failure.dart';
import 'package:quran/Quran/domain/repositories/quran_repository.dart';
import 'package:quran/Quran/murojaah/recite/recite_murojaah_service.dart';
import 'package:quran/Quran/murojaah/tirukan/dengar_tirukan_flow.dart';
import 'package:quran/Quran/murojaah/tirukan/dengar_tirukan_page.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repo implements QuranRepository {
  _Repo(this.surahs);
  final List<Surah> surahs;
  @override
  Future<Either<QuranFailure, List<Surah>>> getSurahs() async => Right(surahs);
  @override
  Future<Either<QuranFailure, Surah>> getSurah(int n) async =>
      Right(surahs.first);
}

/// Recognizer yang menggantung sampai test mengisinya.
class _Rec implements AyatRecognizer {
  final done = Completer<bool?>();
  @override
  Future<bool?> listen(int ayat) => done.future;
  @override
  Future<void> cancel() async {}
}

/// Mesin palsu: initialize() pertama gagal, berikutnya berhasil.
class _FlakyService extends ReciteMurojaahService {
  _FlakyService() : super(surahNumber: 1);
  int calls = 0;
  @override
  Future<void> initialize() async {
    calls++;
    if (calls == 1) {
      errorMessage.value = 'Unduhan gagal. Periksa internet, lalu coba lagi.';
      status.value = ReciteMurojaahStatus.error;
    } else {
      status.value = ReciteMurojaahStatus.ready;
    }
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final scale in [1.0, 2.0]) {
    testWidgets('ayat + status tampil tanpa overflow di 360dp skala $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final surah = Surah(
        number: 1,
        name: 'الفاتحة',
        transliteration: 'Al-Fatihah',
        translation: 'Pembukaan',
        revelationType: RevelationType.meccan,
        totalVerses: 2,
        verses: const [
          Verse(
            number: 1,
            numberInSurah: 1,
            arabic: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
            translation: 'Dengan menyebut nama Allah.',
            transliteration: 'Bismillahir rahmanir rahim',
          ),
          Verse(
            number: 2,
            numberInSurah: 2,
            arabic: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
            translation: 'Segala puji bagi Allah.',
          ),
        ],
      );
      final rec = _Rec();
      final controller = QuranController(_Repo([surah]), const LastReadStore());
      late DengarTirukanFlow flow;
      await tester.pumpWidget(
        QuranThemeScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: DengarTirukanPage(
              surahNumber: 1,
              controller: controller,
              flowBuilder: (s) => flow = DengarTirukanFlow(
                totalAyat: s.totalVerses,
                recognizer: rec,
                gap: () => Duration.zero,
                stopAudio: () async {},
                playAyat: (_) async => true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mikrofon aktif: ayat 1 masih tampil, status giliran pengguna.
      expect(find.text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'), findsOneWidget);
      expect(find.textContaining('Giliranmu, tirukan'), findsOneWidget);
      expect(find.text('Berhenti'), findsOneWidget);
      final stop = tester.getSize(find.byType(FilledButton));
      expect(stop.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);

      // Berhenti -> alur idle, tombol berubah.
      await tester.tap(find.text('Berhenti'));
      await tester.pumpAndSettle();
      expect(find.text('Mulai lagi'), findsOneWidget);
      expect(flow.phase, TirukanPhase.idle);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('persiapan gagal: Coba lagi menjalankan ulang dan memulai alur', (
    tester,
  ) async {
    final surah = Surah(
      number: 1,
      name: 'الفاتحة',
      transliteration: 'Al-Fatihah',
      translation: 'Pembukaan',
      revelationType: RevelationType.meccan,
      totalVerses: 1,
      verses: const [
        Verse(
          number: 1,
          numberInSurah: 1,
          arabic: 'بِسْمِ اللَّهِ',
          translation: 'Dengan menyebut nama Allah.',
        ),
      ],
    );
    final service = _FlakyService();
    final controller = QuranController(_Repo([surah]), const LastReadStore());
    await tester.pumpWidget(
      QuranThemeScope(
        child: MaterialApp(
          home: DengarTirukanPage(
            surahNumber: 1,
            controller: controller,
            serviceBuilder: (_) => service,
            flowBuilder: (s) => DengarTirukanFlow(
              totalAyat: s.totalVerses,
              recognizer: _Rec(),
              gap: () => Duration.zero,
              stopAudio: () async {},
              playAyat: (_) async => true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Unduhan gagal'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(service.calls, 2);
    expect(find.textContaining('Unduhan gagal'), findsNothing);
    expect(find.textContaining('Giliranmu, tirukan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
