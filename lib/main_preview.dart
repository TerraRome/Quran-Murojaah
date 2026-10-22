import 'package:flutter/material.dart';
import 'package:quran/Quran/murojaah/recite/recite_murojaah_page.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';

/// TEMP preview — dihapus setelah verifikasi visual.
void main() => runApp(
      const QuranThemeScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ReciteMurojaahPage(surahNumber: 1),
        ),
      ),
    );
