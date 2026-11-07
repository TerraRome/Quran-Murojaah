import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/data/display_store.dart';
import 'package:quran/Quran/data/font_size_store.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('default: latin & terjemahan tampil, ukuran Sedang', () async {
    final c = QuranThemeController();
    await c.load();
    expect(c.showLatin, isTrue);
    expect(c.showTranslation, isTrue);
    expect(c.arabicFontSize, 28);
    expect(c.latinFontSize, 16);
    expect(c.translationFontSize, 18);
    expect(c.selectedPreset, TextSizePreset.sedang);
  });

  test('toggle tersimpan dan dipulihkan', () async {
    final c = QuranThemeController();
    await c.setShowLatin(false);
    await c.setShowTranslation(false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(DisplayStore.keyShowLatin), isFalse);
    expect(prefs.getBool(DisplayStore.keyShowTranslation), isFalse);

    final c2 = QuranThemeController();
    await c2.load();
    expect(c2.showLatin, isFalse);
    expect(c2.showTranslation, isFalse);
  });

  test('setPreset menulis ketiga kunci dan dipulihkan', () async {
    final c = QuranThemeController();
    await c.setPreset(TextSizePreset.sangatBesar);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('quran_font_size_arabic'), 44);
    expect(prefs.getDouble('quran_font_size_latin'), 24);
    expect(prefs.getDouble('quran_font_size_translation'), 26);

    final c2 = QuranThemeController();
    await c2.load();
    expect(c2.selectedPreset, TextSizePreset.sangatBesar);
  });

  test('ukuran kustom lama: tidak ada preset terpilih', () async {
    SharedPreferences.setMockInitialValues({
      'quran_font_size_arabic': 22.0,
      'quran_font_size_translation': 18.0,
    });
    final c = QuranThemeController();
    await c.load();
    expect(c.selectedPreset, isNull);
  });

  test('resetFontSizes kembali ke Sedang', () async {
    final c = QuranThemeController();
    await c.setPreset(TextSizePreset.kecil);
    await c.resetFontSizes();
    expect(c.selectedPreset, TextSizePreset.sedang);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('quran_font_size_latin'), isFalse);
  });
}
