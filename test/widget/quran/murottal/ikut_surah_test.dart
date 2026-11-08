import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran/Quran/data/datasources/audio_local_datasource.dart';
import 'package:quran/Quran/murottal/application/murottal_controller.dart';
import 'package:quran/Quran/murottal/application/qari_store.dart';
import 'package:quran/Quran/domain/entities/qari.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:quran/Quran/application/quran_controller.dart';
import 'package:quran/Quran/data/last_read_store.dart';
import 'package:quran/Quran/domain/entities/surah.dart';
import 'package:quran/Quran/domain/entities/verse.dart';
import 'package:quran/Quran/domain/failures/quran_failure.dart';
import 'package:quran/Quran/domain/repositories/quran_repository.dart';
import 'package:quran/Quran/presentation/pages/surah_detail_page.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
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

List<Surah> _surahs() {
  Verse verse(int n) => Verse(
    number: n,
    numberInSurah: n,
    arabic: 'بِسْمِ اللهِ الرَّحْمَنِ الرَّحِيمِ',
    translation: 'Terjemahan ayat $n.',
  );
  return [
    Surah(
      number: 1,
      name: 'الفاتحة',
      transliteration: 'Al-Fatihah',
      translation: 'Pembukaan',
      revelationType: RevelationType.meccan,
      totalVerses: 7,
      verses: [for (var i = 1; i <= 7; i++) verse(i)],
    ),
    Surah(
      number: 2,
      name: 'البقرة',
      transliteration: 'Al-Baqarah',
      translation: 'Sapi Betina',
      revelationType: RevelationType.medinan,
      totalVerses: 40,
      verses: [for (var i = 1; i <= 40; i++) verse(i)],
    ),
  ];
}

Future<QuranController> _loaded() async {
  final c = QuranController(
    _FakeQuranRepository(_surahs()),
    const LastReadStore(),
  );
  await c.load();
  return c;
}


class _FakePlayer extends Fake implements AudioPlayer {
  @override
  ProcessingState get processingState => ProcessingState.ready;
  @override
  Stream<PlayerState> get playerStateStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _FakeLocal extends Fake implements AudioLocalDataSource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('murottal lanjut ke surah berikutnya: halaman ikut pindah',
      (tester) async {
    final audio = MurottalController(
      localDataSource: _FakeLocal(),
      qariStore: QariStore.defaults(),
      player: _FakePlayer(),
    );
    await tester.pumpWidget(
      QuranThemeScope(
        child: MaterialApp(
          home: SurahDetailPage(
            surahNumber: 1,
            controller: await _loaded(),
            murottalController: audio,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Al-Fatihah'), findsWidgets);
    expect(find.text('Al-Baqarah'), findsNothing);

    audio.value = MurottalPlaying(
      surahNumber: 2,
      surahName: 'Al-Baqarah',
      currentAyat: 1,
      totalAyat: 40,
      qari: Qari.defaultQari,
      position: Duration.zero,
      duration: const Duration(seconds: 5),
      isFullSurah: true,
    );
    await tester.pumpAndSettle();

    expect(find.text('Al-Baqarah'), findsWidgets);
    expect(find.text('Al-Fatihah'), findsNothing);
  });
}
