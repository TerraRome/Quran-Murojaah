import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/font_size_store.dart';
import '../../data/theme_store.dart';

/// Mode gelap/terang bersama + ukuran font untuk semua halaman bertema "quran".
class QuranThemeController extends ChangeNotifier {
  QuranThemeController({
    FontSizeStore fontSizeStore = const FontSizeStore(),
    ThemeStore themeStore = const ThemeStore(),
  }) : _store = fontSizeStore,
       _themeStore = themeStore;

  bool _dark = false;
  double _arabicFontSize = FontSizeStore.defaultArabic;
  double _translationFontSize = FontSizeStore.defaultTranslation;
  final FontSizeStore _store;
  final ThemeStore _themeStore;

  bool get dark => _dark;
  double get arabicFontSize => _arabicFontSize;
  double get translationFontSize => _translationFontSize;

  /// Balik mode dan simpan pilihannya.
  ///
  /// Tema langsung berubah (tidak menunggu tulis prefs) supaya tombol terasa
  /// seketika; kegagalan penyimpanan tidak boleh membatalkan perubahan.
  void toggle() {
    _dark = !_dark;
    notifyListeners();
    unawaited(_themeStore.saveDark(_dark));
  }

  /// Muat pilihan tema dan ukuran font dari SharedPreferences.
  Future<void> load() async {
    _dark = await _themeStore.loadDark();
    _arabicFontSize = await _store.loadArabic();
    _translationFontSize = await _store.loadTranslation();
    notifyListeners();
  }

  /// Muat ukuran font dari SharedPreferences.
  Future<void> loadFontSizes() async {
    _arabicFontSize = await _store.loadArabic();
    _translationFontSize = await _store.loadTranslation();
    notifyListeners();
  }

  /// Atur ukuran font Arab dan simpan ke SharedPreferences.
  Future<void> setArabicFontSize(double size) async {
    _arabicFontSize = size;
    notifyListeners();
    await _store.saveArabic(size);
  }

  /// Atur ukuran font terjemahan dan simpan ke SharedPreferences.
  Future<void> setTranslationFontSize(double size) async {
    _translationFontSize = size;
    notifyListeners();
    await _store.saveTranslation(size);
  }

  /// Kembalikan ukuran font ke default (18 Arab, 16 terjemahan).
  Future<void> resetFontSizes() async {
    _arabicFontSize = FontSizeStore.defaultArabic;
    _translationFontSize = FontSizeStore.defaultTranslation;
    notifyListeners();
    await _store.resetAll();
  }
}

/// Menyediakan [QuranThemeController] ke seluruh subtree module Quran.
/// Mode dark/light sinkron antar halaman (Splash, Home, Detail, Bookmarks).
class QuranThemeScope extends StatefulWidget {
  const QuranThemeScope({super.key, required this.child});

  final Widget child;

  static QuranThemeController of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_InheritedQuranTheme>();
    assert(inherited != null, 'No QuranThemeScope found in context');
    return inherited!.controller;
  }

  static bool darkOf(BuildContext context) => of(context).dark;

  static void toggleDark(BuildContext context) => of(context).toggle();

  static double arabicFontSizeOf(BuildContext context) =>
      of(context).arabicFontSize;

  static double translationFontSizeOf(BuildContext context) =>
      of(context).translationFontSize;

  static void setArabicFontSize(BuildContext context, double size) =>
      of(context).setArabicFontSize(size);

  static void setTranslationFontSize(BuildContext context, double size) =>
      of(context).setTranslationFontSize(size);

  static void resetFontSizes(BuildContext context) =>
      of(context).resetFontSizes();

  @override
  State<QuranThemeScope> createState() => _QuranThemeScopeState();
}

class _QuranThemeScopeState extends State<QuranThemeScope> {
  final QuranThemeController _controller = QuranThemeController();

  @override
  void initState() {
    super.initState();
    // Tema ikut dipulihkan saat startup: mode gelap tidak boleh hilang setelah
    // aplikasi ditutup.
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedQuranTheme(controller: _controller, child: widget.child);
  }
}

class _InheritedQuranTheme extends InheritedNotifier<QuranThemeController> {
  const _InheritedQuranTheme({required this.controller, required super.child})
      : super(notifier: controller);

  final QuranThemeController controller;
}
