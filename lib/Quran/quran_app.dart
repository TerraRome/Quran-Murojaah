import 'package:flutter/material.dart';

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
      child: MaterialApp.router(
        title: 'Quran App',
        debugShowCheckedModeBanner: false,
        routerConfig: quranRouter,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6B4EFF),
          ),
        ),
      ),
    );
  }
}
