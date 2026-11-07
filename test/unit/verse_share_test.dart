import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/application/verse_share.dart';

void main() {
  String build({String latin = 'Allahu la ilaha illa huwa', bool show = true}) =>
      buildVerseShareText(
        surahName: 'Al-Baqarah',
        ayat: 255,
        arabic: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ',
        transliteration: latin,
        translation: 'Allah, tidak ada tuhan selain Dia.',
        showLatin: show,
      );

  test('dengan latin: Arab, latin, terjemahan, rujukan', () {
    expect(
      build(),
      'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ\n\n'
      'Allahu la ilaha illa huwa\n\n'
      'Allah, tidak ada tuhan selain Dia.\n\n'
      'QS. Al-Baqarah: 255',
    );
  });

  test('latin dimatikan di pengaturan: latin tidak ikut', () {
    expect(build(show: false), isNot(contains('Allahu la')));
    expect(build(show: false), endsWith('QS. Al-Baqarah: 255'));
  });

  test('latin kosong (belum di-prefetch): tanpa baris kosong ganda', () {
    final text = build(latin: '');
    expect(text, isNot(contains('\n\n\n')));
    expect(text.split('\n\n').length, 3);
  });
}
