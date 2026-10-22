import 'package:flutter/material.dart';

import '../../data/quran_tokens.dart';
import '../../domain/entities/verse.dart';
import 'quran_theme_scope.dart';
import 'quran_top_bar.dart';

/// Satu ayat (Figma "Verse"): hanya **strip header** yang berwarna abu —
/// berisi badge nomor ayat (lingkaran ungu) di kiri dan 4 ikon aksi
/// (share, play, bookmark, tafsir) di ujung kanan — lalu teks Arab (Amiri) dan
/// terjemahan di atas latar polos, ditutup divider tipis antar ayat.
class VerseView extends StatelessWidget {
  const VerseView({
    super.key,
    required this.verse,
    required this.surahNumber,
    this.onTap,
    this.showDivider = true,
    this.onPlayTap,
    this.onTafsirTap,
    this.isPlaying = false,
    this.isHighlighted = false,
  });

  final Verse verse;
  final int surahNumber;
  final VoidCallback? onTap;

  /// Tampilkan divider bawah antar ayat (sembunyikan di ayat terakhir surah).
  final bool showDivider;

  /// Callback saat ikon play di-tap (putar/stop ayat ini).
  final VoidCallback? onPlayTap;

  /// Callback saat ikon tafsir (ℹ) di-tap.
  final VoidCallback? onTafsirTap;

  /// True jika ayat ini sedang diputar (ikon play berubah jadi stop).
  final bool isPlaying;

  /// True jika ayat ini adalah ayat aktif dalam mode full-surah —
  /// tampilkan border kiri ungu sebagai highlight.
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    final arabicSize = QuranThemeScope.arabicFontSizeOf(context);
    final translationSize = QuranThemeScope.translationFontSizeOf(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        border: isHighlighted
            ? Border(
                left: BorderSide(
                  color: QuranTokens.arabicNameColor(dark),
                  width: 3,
                ),
              )
            : const Border(),
        borderRadius: isHighlighted
            ? BorderRadius.circular(QuranTokens.radiusCard)
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VerseHeader(
            number: verse.numberInSurah,
            onPlayTap: onPlayTap,
            onTafsirTap: onTafsirTap,
            isPlaying: isPlaying,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Text(
                  verse.displayArabic(surahNumber),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: QuranTokens.amiri(QuranTokens.tsVerseArabic)
                      .copyWith(
                        fontSize: arabicSize,
                        color: QuranTokens.inkColor(dark),
                        height: 1.9,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  verse.translation,
                  style: QuranTokens.poppins(QuranTokens.tsVerseTranslation)
                      .copyWith(
                        fontSize: translationSize,
                        color: QuranTokens.secondaryColor(dark),
                        height: 1.6,
                      ),
                ),
              ],
            ),
          ),
          if (showDivider) ...[
            const SizedBox(height: 16),
            Divider(
              height: 1,
              thickness: 1,
              color: QuranTokens.listDivider(dark),
            ),
          ],
        ],
        ),
      ),
    );
  }
}

/// Strip header abu (5% dark) — lingkaran badge kiri + 4 ikon kanan.
class _VerseHeader extends StatelessWidget {
  const _VerseHeader({
    required this.number,
    this.onPlayTap,
    this.onTafsirTap,
    this.isPlaying = false,
  });

  final int number;
  final VoidCallback? onPlayTap;
  final VoidCallback? onTafsirTap;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    final iconColor = QuranTokens.arabicNameColor(dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: QuranTokens.verseBg(dark),
        borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
      ),
      child: Row(
        children: [
          _VerseNumberBadge(number: number),
          const Spacer(),

          // Share
          QuranHeaderIcon(
            asset: 'assets/quran/share.svg',
            color: iconColor,
          ),
          const SizedBox(width: 16),

          // Play / Stop ayat
          GestureDetector(
            onTap: onPlayTap,
            behavior: HitTestBehavior.opaque,
            child: isPlaying
                ? Icon(Icons.stop_rounded, color: QuranTokens.brandColor(dark), size: 20)
                : QuranHeaderIcon(
                    asset: 'assets/quran/play.svg',
                    color: iconColor,
                  ),
          ),
          const SizedBox(width: 16),

          // Bookmark
          QuranHeaderIcon(
            asset: 'assets/quran/bookmark.svg',
            color: iconColor,
          ),
          const SizedBox(width: 16),

          // Tafsir (ℹ)
          GestureDetector(
            onTap: onTafsirTap,
            behavior: HitTestBehavior.opaque,
            child: Icon(
              Icons.info_outline_rounded,
              color: iconColor,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge nomor ayat — lingkaran ungu `#863ED5` berisi angka putih.
class _VerseNumberBadge extends StatelessWidget {
  const _VerseNumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: QuranTokens.arabicNameColor(dark),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: QuranTokens.poppins(
          QuranTokens.tsVerseNumber,
        ).copyWith(
          // Lingkaran nomor berlatar brandColor, bukan gradient: putih gagal
          // di mode gelap (1.9:1), jadi pakai pasangan onPrimary.
          color: QuranTokens.onPrimaryColor(dark),
          height: 1,
        ),
      ),
    );
  }
}
