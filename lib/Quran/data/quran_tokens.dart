import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens dari Figma "Quran App Concept - Free (Community)".
/// - Light theme: frame #1102 (bg `#FFFFFF`)
/// - Dark theme: frame #132 (bg `#040C23`)
/// Font: Poppins (UI) + Amiri (teks Arab, dari google_fonts).
class QuranTokens {
  const QuranTokens._();

  static const styleName = 'quran';

  // --- Brand colors ---
  static const primary = Color(0xFF672CBC); // splash title, tab aktif
  static const primaryLight = Color(0xFF863ED5); // nama Arab surah, badge ayat
  static const ink = Color(0xFF240F4F); // teks utama surah
  static const secondary = Color(0xFF8789A3); // teks meta surah
  static const peach = Color(0xFFF9B091); // tombol "Get Started"
  static const peachText = Color(0xFF091945); // teks tombol di dark mode

  /// Gradient khas modul (kartu Last Read, header detail, ilus splash).
  static const gradientStart = Color(0xFFDF98FA);
  static const gradientEnd = Color(0xFF9055FF);

  // --- Light theme ---
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFF7F5FB);
  static const lightDivider = Color(0x1A8789A3); // 10% secondary
  static const lightVerseBg = Color(0x0D121931); // 5% #121931
  static const lightShimmerBase = Color(0xFFF0EDF7);
  static const lightShimmerHighlight = Color(0xFFFAF8FE);

  // --- Dark theme ---
  static const darkBackground = Color(0xFF040C23);
  static const darkSurface = Color(0xFF121931);
  static const darkDivider = Color(0x59B0B5D8); // 35% #B0B5D8
  static const darkInk = Color(0xFFFFFFFF);
  static const darkShimmerHighlight = Color(0xFF1C2440);

  static Color background(bool dark) => dark ? darkBackground : lightBackground;
  static Color surface(bool dark) => dark ? darkSurface : lightCard;
  static Color inkColor(bool dark) => dark ? darkInk : ink;
  static Color secondaryColor(bool dark) => dark ? const Color(0xFFA19CC5) : secondary;
  static Color divider(bool dark) => dark ? darkDivider : lightDivider;
  static Color verseBg(bool dark) => dark ? darkSurface : lightVerseBg;
  static Color arabicNameColor(bool dark) => dark ? const Color(0xFFA44AFF) : primaryLight;

  /// Warna brand aktif (judul app, tab aktif) — Figma `#672CBC`.
  static Color brandColor(bool dark) => dark ? const Color(0xFFA44AFF) : primary;

  /// Warna kata yang sudah diucapkan benar (murojaah).
  static Color successColor(bool dark) =>
      dark ? const Color(0xFF66D9A0) : const Color(0xFF1F9D63);

  /// Divider item daftar surah (Figma: rgba(187,196,206,0.35)).
  static Color listDivider(bool dark) => dark ? darkDivider : const Color(0x59BBC4CE);

  /// Warna skeleton shimmer saat loading list.
  static Color shimmerBase(bool dark) => dark ? darkSurface : lightShimmerBase;
  static Color shimmerHighlight(bool dark) =>
      dark ? darkShimmerHighlight : lightShimmerHighlight;

  // --- Radius & shape ---
  static const radiusScreen = 40.0; // border radius frame 375×812
  static const radiusCard = 10.0;
  static const radiusBadge = 13.5; // badge nomor ayat (lingkaran 27×27)
  static const radiusButton = 30.0; // tombol "Get Started"

  // --- Spacing ---
  static const space3 = 4.0;
  static const space5 = 8.0;
  static const space6 = 12.0;
  static const space7 = 16.0;
  static const space8 = 24.0;
  static const space9 = 32.0;

  // --- Typography (Poppins) ---
  static const tsSplashTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 36 / 28,
  );
  static const tsSplashSubtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 26 / 18,
  );
  static const tsButtonLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 26 / 18,
  );
  static const tsAppTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 30 / 20,
  );
  static const tsGreeting = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 26 / 18,
  );
  static const tsUserName = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 34 / 24,
  );
  static const tsTabActive = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 24 / 16,
  );
  static const tsTabInactive = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );
  static const tsSurahName = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
  );
  static const tsSurahMeta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    letterSpacing: 0.5,
  );
  static const tsArabicName = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 32 / 20,
  );
  static const tsDetailName = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 30 / 20,
  );
  static const tsDetailArabic = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 36 / 24,
  );
  static const tsDetailBismillah = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 48 / 30,
  );
  static const tsDetailTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
  );
  static const tsDetailMeaning = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22 / 15,
  );
  static const tsDetailSubtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
  );
  static const tsDetailMeta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 18 / 12,
    letterSpacing: 0.5,
  );
  static const tsVerseArabic = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 32 / 18,
  );
  static const tsVerseTranslation = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 26 / 16,
  );
  static const tsVerseNumber = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
  );
  static const tsLastReadTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 26 / 18,
  );
  static const tsLastReadTag = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
  );
  static const tsLastReadSub = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  );

  /// Font UI default (Poppins).
  static TextStyle poppins([TextStyle? style]) =>
      GoogleFonts.poppins(textStyle: style);

  /// Font teks Arab (Amiri). Dibundel sebagai aset: tanpa jaringan, tanpa
  /// font fallback sistem yang tidak punya glyph Arab (penyebab "kotak-kotak").
  static TextStyle amiri([TextStyle? style]) =>
      (style ?? const TextStyle()).copyWith(fontFamily: 'Amiri');
}
