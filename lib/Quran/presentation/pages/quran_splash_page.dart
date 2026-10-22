import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../data/quran_tokens.dart';
import '../widgets/quran_status_bar.dart';
import '../widgets/quran_theme_scope.dart';

/// Splash screen "Quran App" (Figma "Splash" #1102:917, frame 375×812).
///
/// Layout mengikuti koordinat Figma persis:
/// - Teks di y=86 (judul + subtitle lebar 195)
/// - Ilustrasi SVG 314×450 di y=247
/// - Tombol 185×60 di y=660
/// Layar dibungkus [FittedBox] agar proporsi tetap 375×812 di semua ukuran.
class QuranSplashPage extends StatelessWidget {
  const QuranSplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return QuranStatusBar(
      dark: dark,
      child: Scaffold(
        backgroundColor: QuranTokens.background(dark),
        body: Center(
          child: FittedBox(
            child: SizedBox(
              width: 375,
              height: 812,
              child: Stack(
                children: [
                  Positioned(
                    top: 86,
                    left: 0,
                    right: 0,
                    child: _SplashText(dark: dark),
                  ),
                  Positioned(
                    top: 247,
                    left: 30,
                    right: 30,
                    child: SvgPicture.asset(
                      'assets/quran/splash_illustration.svg',
                      width: 314,
                      height: 450,
                      fit: BoxFit.fill,
                    ),
                  ),
                  Positioned(
                    top: 660,
                    left: 95,
                    right: 95,
                    child: _GetStartedButton(
                      onTap: () => context.push('/home/quran/home'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Blok teks judul + subtitle (Figma #1102:918, column center gap 16).
class _SplashText extends StatelessWidget {
  const _SplashText({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Quran App',
          style: QuranTokens.poppins(QuranTokens.tsSplashTitle)
              .copyWith(color: QuranTokens.brandColor(dark)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 195,
          child: Text(
            'Learn Quran and Recite once everyday',
            textAlign: TextAlign.center,
            style: QuranTokens.poppins(QuranTokens.tsSplashSubtitle)
                .copyWith(color: QuranTokens.secondaryColor(dark)),
          ),
        ),
      ],
    );
  }
}

/// Tombol "Get Started" (185×60, radius 30, isi warna brand).
///
/// Latar memakai [QuranTokens.brandColor], bukan peach lama: putih di atas
/// #F9B091 hanya 1.8:1, gagal WCAG. Brand + [QuranTokens.onPrimaryColor]
/// memberi 6.41:1 (terang) dan 7.86:1 (gelap).
class _GetStartedButton extends StatelessWidget {
  const _GetStartedButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return Material(
      color: QuranTokens.brandColor(dark),
      borderRadius: BorderRadius.circular(QuranTokens.radiusButton),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(QuranTokens.radiusButton),
        child: Container(
          width: 185,
          height: 60,
          alignment: Alignment.center,
          child: Text(
            'Get Started',
            style: QuranTokens.poppins(QuranTokens.tsButtonLarge)
                .copyWith(color: QuranTokens.onPrimaryColor(dark)),
          ),
        ),
      ),
    );
  }
}
