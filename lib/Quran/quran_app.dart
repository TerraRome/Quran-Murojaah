import 'package:flutter/material.dart';

import 'data/quran_tokens.dart';
import 'presentation/widgets/quran_theme_scope.dart';
import 'quran_router.dart';

/// Root widget module Quran.
///
/// [QuranThemeScope] dibungkus di sini (bukan di dalam router) agar
/// state dark/light dan font size tidak reset saat navigasi antar route.
class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return QuranThemeScope(
      child: Builder(
        builder: (context) {
          final dark = QuranThemeScope.darkOf(context);
          return MaterialApp.router(
            title: 'Quran App',
            debugShowCheckedModeBanner: false,
            routerConfig: quranRouter,
            theme: QuranTokens.themeData(false),
            darkTheme: QuranTokens.themeData(true),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          );
        },
      ),
    );
  }
}
