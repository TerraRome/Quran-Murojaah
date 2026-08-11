import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/quran_tokens.dart';

/// Membungkus halaman dengan [AnnotatedRegion] agar status bar & navigation
/// bar menyesuaikan tema (gelap/terang) modul Quran.
class QuranStatusBar extends StatelessWidget {
  const QuranStatusBar({super.key, required this.dark, required this.child});

  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = dark ? Brightness.light : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: QuranTokens.background(dark),
        systemNavigationBarIconBrightness: brightness,
      ),
      child: child,
    );
  }
}
