import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens aplikasi Quran.
///
/// Satu palet, dua mode. Semua warna yang dipakai widget berasal dari sini —
/// tidak ada `Color(0x…)` di lapisan tampilan.
///
/// Kontras terukur (WCAG AA; teks ≥ 4.5:1, grafik ≥ 3:1) dicatat di
/// `test/unit/quran_tokens_test.dart` yang menjalankan penghitungan ulang, jadi
/// angka di dokumen tidak bisa basi tanpa test gagal.
class QuranTokens {
  const QuranTokens._();

  static const styleName = 'quran';

  // --- Palet sumber ---
  // terang / gelap berdampingan supaya satu peran tidak pernah punya dua nilai
  // yang berbeda antar layar.
  static const lightBg = Color(0xFFFAF7F0);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFF1ECE0);
  static const lightBorder = Color(0xFFD9D2C3);
  static const lightText = Color(0xFF1F2A28);
  static const lightTextMuted = Color(0xFF5A6663);
  static const lightPrimary = Color(0xFF0F6B5C);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightActiveBg = Color(0xFFDDF0EA);
  static const lightCorrect = Color(0xFF1B7A3E);
  static const lightWrong = Color(0xFFB3261E);
  static const lightStreak = Color(0xFF8A5A00);

  static const darkBg = Color(0xFF11191A);
  static const darkSurface = Color(0xFF1A2527);
  static const darkSurfaceAlt = Color(0xFF223033);
  static const darkBorder = Color(0xFF334245);
  static const darkText = Color(0xFFEAF1EE);
  static const darkTextMuted = Color(0xFFA5B4B0);
  static const darkPrimary = Color(0xFF4FC3A6);
  static const darkOnPrimary = Color(0xFF08201B);
  static const darkActiveBg = Color(0xFF1F3A36);
  static const darkCorrect = Color(0xFF5FD08A);
  static const darkWrong = Color(0xFFFF8A80);
  static const darkStreak = Color(0xFFE8B94A);

  /// Gradient khas modul (kartu Last Read, header detail, ilus splash).
  ///
  /// Dua nada primary, bukan ungu lama: teks di atasnya putih, dan putih butuh
  /// ≥ 4.5:1 — #14806C memberi 4.85:1, #0B5A4E memberi 8.12:1. Gradient ini
  /// sengaja tidak berubah antar mode karena kartunya selalu berlatar gelap.
  static const gradientStart = Color(0xFF14806C);
  static const gradientEnd = Color(0xFF0B5A4E);

  static Color background(bool dark) => dark ? darkBg : lightBg;
  static Color surface(bool dark) => dark ? darkSurface : lightSurface;
  static Color inkColor(bool dark) => dark ? darkText : lightText;
  static Color secondaryColor(bool dark) => semantic(dark).textMuted;
  static Color divider(bool dark) => semantic(dark).border;
  static Color verseBg(bool dark) => semantic(dark).surfaceAlt;

  /// Nama Arab surah memakai warna brand — satu aksen untuk seluruh modul.
  static Color arabicNameColor(bool dark) => brandColor(dark);

  /// Warna brand aktif (judul app, tab aktif, ikon aksen).
  static Color brandColor(bool dark) => dark ? darkPrimary : lightPrimary;

  /// [brandColor] mengikuti mode tema aktif — untuk widget yang tidak menerima
  /// flag `dark`. Statis [primary] hanya untuk teks di atas latar terang, jadi
  /// jangan dipakai sebagai latar tombol (di gelap `onPrimary` menjadi tinta
  /// gelap dan kontrasnya jatuh ke 2.66:1).
  static Color brandOf(BuildContext context) =>
      brandColor(Theme.of(context).brightness == Brightness.dark);

  /// Pasangan [brandOf] untuk teks/ikon di atasnya.
  static Color onBrandOf(BuildContext context) =>
      onPrimaryColor(Theme.of(context).brightness == Brightness.dark);

  /// [correct] mengikuti mode tema aktif — untuk dialog/snackbar yang tidak
  /// menerima flag `dark`.
  static Color correctOf(BuildContext context) =>
      correct(Theme.of(context).brightness == Brightness.dark);

  /// [wrong] mengikuti mode tema aktif — untuk dialog/snackbar.
  static Color wrongOf(BuildContext context) =>
      wrong(Theme.of(context).brightness == Brightness.dark);

  /// Teks/ikon di atas [wrong] (tombol hapus).
  ///
  /// Mode gelap memakai tinta gelap: putih di atas #FF8A80 hanya 2.28:1.
  static Color onWrong(bool dark) => dark ? darkOnPrimary : lightOnPrimary;

  /// Pasangan [wrongOf] untuk teks/ikon di atasnya.
  static Color onWrongOf(BuildContext context) =>
      onWrong(Theme.of(context).brightness == Brightness.dark);

  /// Teks/ikon di atas [brandColor]. Gelap memakai tinta gelap karena brand
  /// gelap adalah hijau terang (#4FC3A6) — putih di atasnya hanya 1.9:1.
  static Color onPrimaryColor(bool dark) => dark ? darkOnPrimary : lightOnPrimary;

  // --- Token semantik ---
  //
  // Warna peran, bukan warna hiasan: satu nama untuk satu arti, dipakai di
  // semua layar. Mode terang & gelap disediakan berdampingan.

  /// Permukaan kedua (kartu di atas latar, kolom terpilih).
  static Color surfaceAlt(bool dark) => semantic(dark).surfaceAlt;

  /// Garis batas halus (kartu, kolom, pemisah).
  static Color border(bool dark) => semantic(dark).border;

  /// Teks pendukung: label, keterangan, meta.
  static Color textMuted(bool dark) => semantic(dark).textMuted;

  /// [textMuted] mengikuti mode tema aktif — untuk widget yang tidak menerima
  /// flag `dark` (dialog, sheet) tapi tetap harus terbaca di kedua mode.
  static Color mutedOf(BuildContext context) =>
      textMuted(Theme.of(context).brightness == Brightness.dark);

  /// Latar sorotan untuk keadaan aktif/terpilih.
  static Color activeBg(bool dark) => semantic(dark).activeBg;

  /// Bacaan benar (ikon centang + warna).
  static Color correct(bool dark) => semantic(dark).correct;

  /// Bacaan salah (ikon + garis bawah bergelombang + warna).
  static Color wrong(bool dark) => semantic(dark).wrong;

  /// Angka streak.
  static Color streak(bool dark) => semantic(dark).streak;

  /// Angka XP / hadiah.
  static Color xp(bool dark) => semantic(dark).xp;

  /// Kata yang belum terbuka (blok redaksi).
  static Color hidden(bool dark) => semantic(dark).hidden;

  /// Bayangan kartu: tipis di terang, tidak ada di gelap.
  ///
  /// Di gelap, kedalaman dibangun oleh [border] — bayangan hitam di atas latar
  /// gelap tidak terbaca dan hanya menambah derau.
  static List<BoxShadow> cardShadow(bool dark) => dark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ];

  static QuranSemanticColors semantic(bool dark) =>
      dark ? QuranSemanticColors.dark : QuranSemanticColors.light;

  /// [ThemeData] modul Quran: skema warna turunan token + warna semantik
  /// terdaftar sebagai extension supaya bisa dibaca lewat `Theme.of(context)`.
  static ThemeData themeData(bool dark) {
    final semantic = QuranTokens.semantic(dark);
    final base = ColorScheme.fromSeed(
      seedColor: brandColor(dark),
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: base.copyWith(
        primary: brandColor(dark),
        onPrimary: onPrimaryColor(dark),
        secondary: brandColor(dark),
        onSecondary: onPrimaryColor(dark),
        surface: surface(dark),
        onSurface: inkColor(dark),
        error: semantic.wrong,
        onError: dark ? darkOnPrimary : lightOnPrimary,
        outline: semantic.border,
        surfaceContainerHighest: semantic.surfaceAlt,
      ),
      scaffoldBackgroundColor: background(dark),
      extensions: [semantic],
    );
  }

  /// Warna semantik dari tema terdekat, dengan jatuh ke token statis bila
  /// widget diuji tanpa [ThemeData] modul Quran.
  static QuranSemanticColors semanticOf(BuildContext context) =>
      Theme.of(context).extension<QuranSemanticColors>() ??
      semantic(Theme.of(context).brightness == Brightness.dark);

  /// Divider item daftar surah.
  static Color listDivider(bool dark) => semantic(dark).border;

  /// Warna skeleton shimmer saat loading list.
  static Color shimmerBase(bool dark) => semantic(dark).surfaceAlt;
  static Color shimmerHighlight(bool dark) => surface(dark);

  // --- Radius & shape ---
  static const radiusSmall = 8.0;
  static const radiusMedium = 14.0;
  static const radiusLarge = 20.0;
  static const radiusCard = radiusMedium;
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

/// Warna semantik per tema — dipetakan dari token design system web.
///
/// Kontras terhadap latar mode masing-masing diukur ulang oleh
/// `test/unit/quran_tokens_test.dart` (WCAG AA: teks ≥ 4.5:1, grafik ≥ 3:1).
class QuranSemanticColors extends ThemeExtension<QuranSemanticColors> {
  const QuranSemanticColors({
    required this.surfaceAlt,
    required this.border,
    required this.textMuted,
    required this.activeBg,
    required this.correct,
    required this.wrong,
    required this.streak,
    required this.xp,
    required this.hidden,
  });

  final Color surfaceAlt;
  final Color border;
  final Color textMuted;
  final Color activeBg;
  final Color correct;
  final Color wrong;
  final Color streak;
  final Color xp;
  final Color hidden;

  static const light = QuranSemanticColors(
    surfaceAlt: QuranTokens.lightSurfaceAlt,
    border: QuranTokens.lightBorder,
    textMuted: QuranTokens.lightTextMuted,
    activeBg: QuranTokens.lightActiveBg,
    correct: QuranTokens.lightCorrect,
    wrong: QuranTokens.lightWrong,
    streak: QuranTokens.lightStreak,
    xp: QuranTokens.lightStreak,
    hidden: QuranTokens.lightBorder,
  );

  static const dark = QuranSemanticColors(
    surfaceAlt: QuranTokens.darkSurfaceAlt,
    border: QuranTokens.darkBorder,
    textMuted: QuranTokens.darkTextMuted,
    activeBg: QuranTokens.darkActiveBg,
    correct: QuranTokens.darkCorrect,
    wrong: QuranTokens.darkWrong,
    streak: QuranTokens.darkStreak,
    xp: QuranTokens.darkStreak,
    hidden: QuranTokens.darkBorder,
  );

  @override
  QuranSemanticColors copyWith({
    Color? surfaceAlt,
    Color? border,
    Color? textMuted,
    Color? activeBg,
    Color? correct,
    Color? wrong,
    Color? streak,
    Color? xp,
    Color? hidden,
  }) =>
      QuranSemanticColors(
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        border: border ?? this.border,
        textMuted: textMuted ?? this.textMuted,
        activeBg: activeBg ?? this.activeBg,
        correct: correct ?? this.correct,
        wrong: wrong ?? this.wrong,
        streak: streak ?? this.streak,
        xp: xp ?? this.xp,
        hidden: hidden ?? this.hidden,
      );

  @override
  QuranSemanticColors lerp(QuranSemanticColors? other, double t) {
    if (other == null) return this;
    return QuranSemanticColors(
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      activeBg: Color.lerp(activeBg, other.activeBg, t)!,
      correct: Color.lerp(correct, other.correct, t)!,
      wrong: Color.lerp(wrong, other.wrong, t)!,
      streak: Color.lerp(streak, other.streak, t)!,
      xp: Color.lerp(xp, other.xp, t)!,
      hidden: Color.lerp(hidden, other.hidden, t)!,
    );
  }
}
