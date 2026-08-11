import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/quran_tokens.dart';
import '../../domain/entities/surah.dart';
import 'quran_theme_scope.dart';

/// Item daftar surah (Figma "List Item"): nomor dalam avatar 36×36,
/// nama latin + meta (Mekkah · 7 Ayat), nama Arab di kanan.
class SurahCard extends StatelessWidget {
  const SurahCard({super.key, required this.surah, this.onTap});

  final Surah surah;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    final secondary = QuranTokens.secondaryColor(dark);
    final arabicColor = QuranTokens.arabicNameColor(dark);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _SurahNumberBadge(number: surah.number),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        surah.revelationType.label,
                        style: QuranTokens.poppins(QuranTokens.tsSurahMeta)
                            .copyWith(color: secondary, letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: secondary.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${surah.totalVerses} Ayat',
                        style: QuranTokens.poppins(QuranTokens.tsSurahMeta)
                            .copyWith(color: secondary, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    surah.transliteration,
                    style: QuranTokens.poppins(QuranTokens.tsSurahName)
                        .copyWith(color: QuranTokens.inkColor(dark)),
                  ),
                ],
              ),
            ),
            Text(
              surah.name,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: QuranTokens.amiri(QuranTokens.tsArabicName)
                  .copyWith(color: arabicColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nomor surah di atas avatar (Figma "muslim (1) 1", 36×36).
class _SurahNumberBadge extends StatelessWidget {
  const _SurahNumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SvgPicture.asset(
            'assets/quran/muslim_avatar.svg',
            width: 36,
            height: 36,
            fit: BoxFit.cover,
          ),
          Text(
            '$number',
            style: QuranTokens.poppins(QuranTokens.tsVerseNumber)
                .copyWith(color: QuranTokens.inkColor(dark)),
          ),
        ],
      ),
    );
  }
}
