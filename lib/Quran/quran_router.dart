import 'package:go_router/go_router.dart';

import 'application/quran_dependencies.dart';
import 'murojaah/presentation/pages/hafalan_map_page.dart';
import 'murojaah/recite/recite_murojaah_page.dart';
import 'murottal/presentation/pages/murottal_settings_page.dart';
import 'presentation/pages/quran_home_page.dart';
import 'presentation/pages/quran_splash_page.dart';
import 'presentation/pages/settings_page.dart';
import 'presentation/pages/surah_detail_page.dart';
import 'presentation/widgets/quran_theme_scope.dart';

/// GoRouter untuk module Quran.
///
/// Semua route dibungkus [QuranThemeScope] via [ShellRoute] agar
/// state dark/light dan font size sinkron antar halaman.
///
/// Route tree:
///   /                                        → QuranSplashPage
///   /home/quran/home                         → QuranHomePage
///   /home/quran/surah/:number                → SurahDetailPage
///   /home/quran/settings                     → SettingsPage
///   /home/quran/murottal-settings            → MurottalSettingsPage
///   /home/quran/murojaah/map                 → HafalanMapPage
///   /home/quran/murojaah/surah/:number       → ReciteMurojaahPage
final GoRouter quranRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => QuranThemeScope(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const QuranSplashPage(),
        ),
        GoRoute(
          path: '/home/quran/home',
          builder: (context, state) => QuranHomePage(
            controller: QuranDependencies.controller,
            doaController: QuranDependencies.doaController,
            shalatController: QuranDependencies.shalatController,
            murojaahProgress: QuranDependencies.murojaahProgress,
          ),
        ),
        GoRoute(
          path: '/home/quran/surah/:number',
          builder: (context, state) {
            final number = int.parse(state.pathParameters['number']!);
            return SurahDetailPage(
              surahNumber: number,
              controller: QuranDependencies.controller,
              readingProgress: QuranDependencies.murojaahProgress,
            );
          },
        ),
        GoRoute(
          path: '/home/quran/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/home/quran/murottal-settings',
          builder: (context, state) => const MurottalSettingsPage(),
        ),
        GoRoute(
          path: '/home/quran/murojaah/map',
          builder: (context, state) => HafalanMapPage(
            controller: QuranDependencies.controller,
            progress: QuranDependencies.murojaahProgress,
          ),
        ),
        GoRoute(
          path: '/home/quran/murojaah/surah/:number',
          builder: (context, state) {
            final number = int.parse(state.pathParameters['number']!);
            return ReciteMurojaahPage(
              surahNumber: number,
              progress: QuranDependencies.murojaahProgress,
            );
          },
        ),
      ],
    ),
  ],
);
