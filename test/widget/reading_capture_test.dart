import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:quran/Quran/application/quran_controller.dart';
import 'package:quran/Quran/data/datasources/equran_remote_datasource.dart';
import 'package:quran/Quran/data/last_read_store.dart';
import 'package:quran/Quran/data/models/surah_audio_model.dart';
import 'package:quran/Quran/data/models/tafsir_response_model.dart';
import 'package:quran/Quran/doa/application/doa_controller.dart';
import 'package:quran/Quran/doa/data/datasources/doa_local_datasource.dart';
import 'package:quran/Quran/doa/data/datasources/doa_remote_datasource.dart';
import 'package:quran/Quran/doa/data/models/doa_model.dart';
import 'package:quran/Quran/doa/domain/entities/doa.dart';
import 'package:quran/Quran/doa/presentation/pages/doa_list_page.dart';
import 'package:quran/Quran/domain/entities/surah.dart';
import 'package:quran/Quran/domain/entities/tafsir.dart';
import 'package:quran/Quran/domain/entities/verse.dart';
import 'package:quran/Quran/domain/failures/quran_failure.dart';
import 'package:quran/Quran/domain/repositories/quran_repository.dart';
import 'package:quran/Quran/murojaah/presentation/widgets/today_activity_summary.dart';
import 'package:quran/Quran/murojaah/progress/activity_entry.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_controller.dart';
import 'package:quran/Quran/murojaah/progress/progress_service.dart';
import 'package:quran/Quran/murojaah/progress/reading_dwell.dart';
import 'package:quran/Quran/presentation/pages/surah_detail_page.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:quran/Quran/tafsir/application/tafsir_controller.dart';
import 'package:quran/Quran/tafsir/presentation/widgets/tafsir_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeQuranRepository implements QuranRepository {
  _FakeQuranRepository(this.surahs);

  final List<Surah> surahs;

  @override
  Future<Either<QuranFailure, List<Surah>>> getSurahs() async => Right(surahs);

  @override
  Future<Either<QuranFailure, Surah>> getSurah(int number) async =>
      Right(surahs.firstWhere((s) => s.number == number));
}

class _FakeEquran implements EquranRemoteDataSource {
  @override
  Future<SurahAudioModel> getSurahAudio(int surahNumber) async =>
      SurahAudioModel(nomor: surahNumber, audioFull: const {}, ayat: const []);

  @override
  Future<TafsirResponseModel> getTafsir(int surahNumber) async =>
      TafsirResponseModel(
        nomor: surahNumber,
        tafsir: const [Tafsir(ayat: 1, teks: 'Tafsir ayat satu.')],
      );

  @override
  Future<Map<int, String>> getTransliterations(int surahNumber) async =>
      const {};
}

class _FakeDoaRemote implements DoaRemoteDataSource {
  @override
  Future<List<DoaModel>> getDoas() async => const [];

  @override
  Future<DoaModel> getDoaDetail(int id) => throw UnimplementedError();
}

Verse _verse(int n) => Verse(
  number: n,
  numberInSurah: n,
  arabic: 'بِسْمِ اللهِ',
  translation: 'Terjemahan ayat $n.',
);

List<Surah> _surahs() => [
  Surah(
    number: 1,
    name: 'الفاتحة',
    transliteration: 'Al-Fatihah',
    translation: 'Pembukaan',
    revelationType: RevelationType.meccan,
    totalVerses: 7,
    verses: [for (var i = 1; i <= 7; i++) _verse(i)],
  ),
];

Doa _doa() => const Doa(
  id: 12,
  grup: 'Doa Harian',
  nama: 'Doa Sebelum Makan',
  ar: 'بِسْمِ اللهِ',
  tr: 'Bismillah',
  idn: 'Dengan nama Allah',
  tentang: 'Dibaca sebelum makan.',
  tag: ['makan'],
);

/// Layar 360 px dengan teks diperbesar — kondisi tersempit yang harus aman.
Future<void> _pumpNarrow(
  WidgetTester tester,
  Widget child, {
  double textScale = 2.0,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    QuranThemeScope(
      child: MaterialApp(
        builder: (context, inner) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: inner!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<MurojaahProgressController> _progress() async {
  final c = MurojaahProgressController(store: MemoryActivityStore());
  await c.load();
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MarkReadButton', () {
    testWidgets('lebar 360 + teks 1.5x: label utuh, tinggi ≥ 48, tidak overflow', (
      tester,
    ) async {
      var taps = 0;
      await _pumpNarrow(
        tester,
        Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox.expand()),
              MarkReadButton(onPressed: () => taps++),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Tandai sudah dibaca'), findsOneWidget);
      expect(tester.getSize(find.byType(MarkReadButton)).height, greaterThan(47));

      await tester.tap(find.text('Tandai sudah dibaca'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('tidak menutupi konten: bar ada di bawah area konten', (
      tester,
    ) async {
      await _pumpNarrow(
        tester,
        Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Container(
                  key: const ValueKey('content'),
                  color: const Color(0xFF000000),
                ),
              ),
              MarkReadButton(onPressed: () {}),
            ],
          ),
        ),
      );

      final content = tester.getRect(find.byKey(const ValueKey('content')));
      final bar = tester.getRect(find.byType(MarkReadButton));
      expect(bar.top, greaterThanOrEqualTo(content.bottom));
    });
  });

  group('SurahDetailPage — pencatatan bacaan', () {
    testWidgets('ayat tampil, tombol tandai mencatat ayat yang tampil', (
      tester,
    ) async {
      final progress = await _progress();
      final controller = QuranController(
        _FakeQuranRepository(_surahs()),
        const LastReadStore(),
      );
      await _pumpNarrow(
        tester,
        SurahDetailPage(
          surahNumber: 1,
          controller: controller,
          readingProgress: progress,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Al-Fatihah'), findsWidgets);
      expect(find.text('Tandai sudah dibaca'), findsOneWidget);
      expect(progress.entries, isEmpty, reason: 'belum ada yang ditandai');

      await tester.tap(find.text('Tandai sudah dibaca'));
      await tester.pumpAndSettle();

      expect(progress.entries, isNotEmpty);
      final e = progress.entries.first;
      expect(e.type, ActivityType.quranRead);
      expect(e.surahNumber, 1);
      expect(e.fromVerse, 1);
      expect(e.toVerse, greaterThanOrEqualTo(e.fromVerse));
      expect(e.toVerse, lessThanOrEqualTo(7));
      // Semua ayat dalam satu rentang berurutan — digabung, bukan per ayat.
      expect(progress.entries.length, 1);
    });

    testWidgets('tanpa readingProgress: tombol tetap aman ditekan', (
      tester,
    ) async {
      final controller = QuranController(
        _FakeQuranRepository(_surahs()),
        const LastReadStore(),
      );
      await _pumpNarrow(
        tester,
        SurahDetailPage(surahNumber: 1, controller: controller),
      );
      await tester.tap(find.text('Tandai sudah dibaca'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('TafsirBottomSheet — pencatatan tafsir', () {
    testWidgets('menampilkan tafsir aktif dan mencatat satu ayat', (
      tester,
    ) async {
      final progress = await _progress();
      final tafsir = TafsirController(datasource: _FakeEquran());
      await tafsir.open(1, 1);

      await _pumpNarrow(
        tester,
        Scaffold(
          body: TafsirBottomSheet(
            controller: tafsir,
            verses: [for (var i = 1; i <= 7; i++) _verse(i)],
            surahNumber: 1,
            totalAyat: 7,
            readingProgress: progress,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Tafsir Ayat 1'), findsOneWidget);
      expect(find.text('Tafsir ayat satu.'), findsOneWidget);
      expect(find.text('Tandai tafsir ini sudah dibaca'), findsOneWidget);
      expect(progress.entries, isEmpty);

      await tester.tap(find.text('Tandai tafsir ini sudah dibaca'));
      await tester.pumpAndSettle();

      final e = progress.entries.single;
      expect(e.type, ActivityType.tafsir);
      expect(e.surahNumber, 1);
      expect(e.fromVerse, 1);
      expect(e.toVerse, 1);
    });
  });

  group('TodayActivitySummary', () {
    testWidgets('empat baris, status teks bukan warna saja, aman di 360 + 2x', (
      tester,
    ) async {
      final snapshot = ProgressService([
        ActivityEntry(
          at: DateTime(2026, 10, 22, 9),
          surahNumber: 1,
          fromVerse: 1,
          toVerse: 7,
          type: ActivityType.quranRead,
        ),
        ActivityEntry(
          at: DateTime(2026, 10, 22, 9, 5),
          surahNumber: ActivityEntry.noSurah,
          fromVerse: 1,
          toVerse: 1,
          type: ActivityType.doa,
          refId: '12',
        ),
      ]).snapshot(now: DateTime(2026, 10, 22, 20), goal: DailyGoal.sedang);

      await _pumpNarrow(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: TodayActivitySummary(snapshot: snapshot),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Hari ini'), findsOneWidget);
      for (final type in ActivityType.values) {
        expect(find.text(type.label), findsOneWidget);
      }
      expect(find.text('Selesai'), findsNWidgets(2));
      expect(find.text('0 dari 15 ayat'), findsOneWidget);
      expect(find.text('0 dari 1 ayat'), findsOneWidget);
    });
  });

  group('DoaDetailPage — pencatatan doa', () {
    testWidgets('menampilkan doa dan mencatat refId doa', (tester) async {
      final progress = await _progress();
      final controller = DoaController(
        remote: _FakeDoaRemote(),
        local: DoaLocalDataSource(),
      );

      await _pumpNarrow(
        tester,
        DoaDetailPage(
          doa: _doa(),
          isBookmarked: false,
          onBookmarkTap: () {},
          controller: controller,
          readingProgress: progress,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Doa Sebelum Makan'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Tandai sudah dibaca'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tandai sudah dibaca'));
      await tester.pumpAndSettle();

      final e = progress.entries.single;
      expect(e.type, ActivityType.doa);
      expect(e.refId, '12');
      expect(e.surahNumber, ActivityEntry.noSurah);
      expect(e.count, 1);
    });
  });
}
