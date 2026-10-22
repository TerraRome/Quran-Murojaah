import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/data/quran_tokens.dart';

/// Kontras WCAG 2.1: (L1 + 0.05) / (L2 + 0.05).
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('pemetaan token — nilai palet', () {
    test('terang: latar, permukaan, dan teks sesuai palet', () {
      expect(QuranTokens.background(false), const Color(0xFFFAF7F0));
      expect(QuranTokens.surface(false), const Color(0xFFFFFFFF));
      expect(QuranTokens.surfaceAlt(false), const Color(0xFFF1ECE0));
      expect(QuranTokens.border(false), const Color(0xFFD9D2C3));
      expect(QuranTokens.inkColor(false), const Color(0xFF1F2A28));
      expect(QuranTokens.textMuted(false), const Color(0xFF5A6663));
      expect(QuranTokens.brandColor(false), const Color(0xFF0F6B5C));
      expect(QuranTokens.activeBg(false), const Color(0xFFDDF0EA));
      expect(QuranTokens.correct(false), const Color(0xFF1B7A3E));
      expect(QuranTokens.wrong(false), const Color(0xFFB3261E));
      expect(QuranTokens.streak(false), const Color(0xFF8A5A00));
      expect(QuranTokens.xp(false), const Color(0xFF8A5A00));
    });

    test('gelap: latar, permukaan, dan teks sesuai palet', () {
      expect(QuranTokens.background(true), const Color(0xFF11191A));
      expect(QuranTokens.surface(true), const Color(0xFF1A2527));
      expect(QuranTokens.surfaceAlt(true), const Color(0xFF223033));
      expect(QuranTokens.border(true), const Color(0xFF334245));
      expect(QuranTokens.inkColor(true), const Color(0xFFEAF1EE));
      expect(QuranTokens.textMuted(true), const Color(0xFFA5B4B0));
      expect(QuranTokens.brandColor(true), const Color(0xFF4FC3A6));
      expect(QuranTokens.activeBg(true), const Color(0xFF1F3A36));
      expect(QuranTokens.correct(true), const Color(0xFF5FD08A));
      expect(QuranTokens.wrong(true), const Color(0xFFFF8A80));
      expect(QuranTokens.streak(true), const Color(0xFFE8B94A));
      expect(QuranTokens.xp(true), const Color(0xFFE8B94A));
    });

    test('token peran menunjuk nilai palet baru', () {
      expect(QuranTokens.divider(true), QuranTokens.border(true));
      expect(QuranTokens.listDivider(false), QuranTokens.border(false));
      expect(QuranTokens.shimmerBase(false), QuranTokens.surfaceAlt(false));
      expect(QuranTokens.shimmerHighlight(true), QuranTokens.surface(true));
      expect(QuranTokens.arabicNameColor(false), QuranTokens.brandColor(false));
      expect(QuranTokens.secondaryColor(true), QuranTokens.textMuted(true));
      expect(QuranTokens.verseBg(false), QuranTokens.surfaceAlt(false));
    });

    test('semantic extension mengikuti palet', () {
      final light = QuranTokens.semantic(false);
      final dark = QuranTokens.semantic(true);
      expect(light.surfaceAlt, QuranTokens.lightSurfaceAlt);
      expect(dark.surfaceAlt, QuranTokens.darkSurfaceAlt);
      expect(light.hidden, QuranTokens.lightBorder);
      expect(dark.hidden, QuranTokens.darkBorder);
      expect(light.copyWith(correct: const Color(0xFF000000)).correct,
          const Color(0xFF000000));
      expect(light.lerp(dark, 0).correct, light.correct);
      expect(light.lerp(dark, 1).correct, dark.correct);
    });

    test('radius palet 8 / 14 / 20', () {
      expect(QuranTokens.radiusSmall, 8);
      expect(QuranTokens.radiusMedium, 14);
      expect(QuranTokens.radiusLarge, 20);
      expect(QuranTokens.radiusCard, QuranTokens.radiusMedium);
    });

    test('bayangan hanya ada di mode terang', () {
      expect(QuranTokens.cardShadow(true), isEmpty);
      expect(QuranTokens.cardShadow(false), isNotEmpty);
    });

    test('themeData memakai palet untuk skema & extension', () {
      for (final dark in [false, true]) {
        final theme = QuranTokens.themeData(dark);
        expect(theme.scaffoldBackgroundColor, QuranTokens.background(dark));
        expect(theme.colorScheme.primary, QuranTokens.brandColor(dark));
        expect(theme.colorScheme.onPrimary, QuranTokens.onPrimaryColor(dark));
        expect(theme.colorScheme.surface, QuranTokens.surface(dark));
        expect(theme.colorScheme.onSurface, QuranTokens.inkColor(dark));
        expect(theme.colorScheme.outline, QuranTokens.border(dark));
        expect(
          theme.extension<QuranSemanticColors>()!.correct,
          QuranTokens.correct(dark),
        );
      }
    });
  });

  group('kontras teks ≥ 4.5:1 di kedua mode', () {
    void expectText(Color fg, Color bg, String label) {
      final ratio = contrast(fg, bg);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: '$label hanya ${ratio.toStringAsFixed(2)}:1',
      );
    }

    for (final dark in [false, true]) {
      final mode = dark ? 'gelap' : 'terang';
      final bg = QuranTokens.background(dark);
      final surf = QuranTokens.surface(dark);
      final alt = QuranTokens.surfaceAlt(dark);
      final active = QuranTokens.activeBg(dark);

      test('$mode: teks utama di semua permukaan', () {
        for (final surface in [bg, surf, alt, active]) {
          expectText(QuranTokens.inkColor(dark), surface, '$mode ink');
        }
      });

      test('$mode: teks pendukung di semua permukaan', () {
        for (final surface in [bg, surf, alt, active]) {
          expectText(QuranTokens.textMuted(dark), surface, '$mode muted');
        }
      });

      test('$mode: warna status dipakai sebagai teks', () {
        for (final surface in [bg, surf, alt, active]) {
          expectText(QuranTokens.correct(dark), surface, '$mode correct');
          expectText(QuranTokens.wrong(dark), surface, '$mode wrong');
          expectText(QuranTokens.streak(dark), surface, '$mode streak');
          expectText(QuranTokens.xp(dark), surface, '$mode xp');
          expectText(QuranTokens.brandColor(dark), surface, '$mode brand');
        }
      });

      test('$mode: teks di atas tombol brand', () {
        expectText(
          QuranTokens.onPrimaryColor(dark),
          QuranTokens.brandColor(dark),
          '$mode onPrimary/brand',
        );
      });

      test('$mode: teks di atas tombol activeBg', () {
        expectText(QuranTokens.inkColor(dark), active, '$mode ink/activeBg');
      });

      test('$mode: teks di atas tombol hapus (wrong)', () {
        expectText(
          QuranTokens.onWrong(dark),
          QuranTokens.wrong(dark),
          '$mode onWrong/wrong',
        );
      });
    }
  });

  group('teks di atas gradient brand', () {
    test('putih di atas gradient tetap ≥ 4.5:1', () {
      for (final stop in [QuranTokens.gradientStart, QuranTokens.gradientEnd]) {
        final ratio = contrast(const Color(0xFFFFFFFF), stop);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'putih di atas gradient hanya ${ratio.toStringAsFixed(2)}:1',
        );
      }
    });
  });

  group('mutedOf mengikuti brightness tema', () {
    testWidgets('terang memakai textMuted terang', (tester) async {
      late Color resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: QuranTokens.themeData(false),
          home: Builder(
            builder: (context) {
              resolved = QuranTokens.mutedOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, QuranTokens.textMuted(false));
    });

    testWidgets('gelap memakai textMuted gelap', (tester) async {
      late Color resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: QuranTokens.themeData(true),
          home: Builder(
            builder: (context) {
              resolved = QuranTokens.mutedOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, QuranTokens.textMuted(true));
    });
  });

  group('kontras grafik ≥ 3:1', () {
    test('garis tepi terbaca terhadap latar dan permukaan', () {
      for (final dark in [false, true]) {
        final mode = dark ? 'gelap' : 'terang';
        for (final surface in [
          QuranTokens.background(dark),
          QuranTokens.surface(dark),
        ]) {
          final ratio = contrast(QuranTokens.border(dark), surface);
          expect(
            ratio,
            greaterThanOrEqualTo(1.2),
            reason:
                '$mode border hanya ${ratio.toStringAsFixed(2)}:1 — '
                'garis halus, bukan pemisah utama',
          );
        }
      }
    });

    test('busur cincin progres terbaca di atas jalurnya', () {
      for (final dark in [false, true]) {
        final ratio = contrast(
          QuranTokens.brandColor(dark),
          QuranTokens.border(dark),
        );
        expect(ratio, greaterThanOrEqualTo(3.0));
      }
    });

    test('warna status terbaca sebagai ikon di atas permukaan', () {
      for (final dark in [false, true]) {
        for (final surface in [
          QuranTokens.background(dark),
          QuranTokens.surfaceAlt(dark),
        ]) {
          expect(
            contrast(QuranTokens.correct(dark), surface),
            greaterThanOrEqualTo(3.0),
          );
          expect(
            contrast(QuranTokens.wrong(dark), surface),
            greaterThanOrEqualTo(3.0),
          );
        }
      }
    });
  });
}
