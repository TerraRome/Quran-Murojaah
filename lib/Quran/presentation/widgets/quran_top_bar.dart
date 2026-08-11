import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/quran_tokens.dart';
import 'quran_theme_scope.dart';

/// Top bar umum module Quran (Figma "Top", 375×47):
/// ikon menu kiri, judul tengah, ikon aksi kanan.
class QuranTopBar extends StatelessWidget {
  const QuranTopBar({
    super.key,
    required this.title,
    this.titleColor,
    this.onSearch,
    this.onThemeToggle,
    this.leading,
  });

  final String title;
  final Color? titleColor;
  final VoidCallback? onSearch;
  final VoidCallback? onThemeToggle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (leading != null)
            SizedBox(width: 30, height: 30, child: leading)
          else
            const SizedBox(width: 30, height: 30),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: QuranTokens.poppins(QuranTokens.tsAppTitle)
                  .copyWith(color: titleColor ?? QuranTokens.inkColor(dark)),
            ),
          ),
          if (onThemeToggle != null)
            IconButton(
              onPressed: onThemeToggle,
              icon: Icon(
                dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 24,
              ),
              color: QuranTokens.inkColor(dark),
            ),
          if (onSearch != null)
            IconButton(
              onPressed: onSearch,
              padding: EdgeInsets.zero,
              icon: const QuranHeaderIcon(asset: 'assets/quran/search_line.svg'),
            ),
        ],
      ),
    );
  }
}

/// Ikon header module (Figma "menu-2-line" / "search-line") — SVG line
/// 24×24, warna sekunder (#8789A3 light / #A19CC5 dark).
class QuranHeaderIcon extends StatelessWidget {
  const QuranHeaderIcon({super.key, required this.asset, this.color});

  final String asset;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return SvgPicture.asset(
      asset,
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(
        color ?? QuranTokens.secondaryColor(dark),
        BlendMode.srcIn,
      ),
    );
  }
}
