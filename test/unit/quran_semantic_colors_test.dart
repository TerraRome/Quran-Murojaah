import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/data/quran_tokens.dart';

/// WCAG 2.x relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const backgrounds = ['background', 'surface', 'surfaceAlt'];

  for (final dark in [false, true]) {
    final mode = dark ? 'gelap' : 'terang';
    final tokens = QuranTokens.semantic(dark);
    final bgs = {
      'background': QuranTokens.background(dark),
      'surface': QuranTokens.surface(dark),
      'surfaceAlt': tokens.surfaceAlt,
    };

    for (final role in {
      'correct': tokens.correct,
      'wrong': tokens.wrong,
      'textMuted': tokens.textMuted,
      'streak': tokens.streak,
      'xp': tokens.xp,
    }.entries) {
      for (final bg in bgs.entries) {
        test('kontras $mode: ${role.key} di atas ${bg.key} ≥ 4.5:1', () {
          final ratio = contrast(role.value, bg.value);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${role.key} vs ${bg.key} = '
                '${ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    }

    test('kontras $mode: teks utama di atas latar ≥ 4.5:1', () {
      for (final bg in bgs.values) {
        expect(contrast(QuranTokens.inkColor(dark), bg),
            greaterThanOrEqualTo(4.5));
      }
    });
  }

  test('warna benar dan salah dibedakan rona, bukan cuma gelap-terang', () {
    for (final dark in [false, true]) {
      final t = QuranTokens.semantic(dark);
      final hc = HSLColor.fromColor(t.correct).hue;
      final hw = HSLColor.fromColor(t.wrong).hue;
      final delta = (hc - hw).abs();
      final hueGap = delta > 180 ? 360 - delta : delta;
      expect(hueGap, greaterThan(60), reason: 'jarak rona $hueGap°');
      // Kontras luminansi kecil di mode gelap — karena itu bentuk (centang,
      // garis bergelombang) wajib ikut menandai, tidak warna saja.
      expect(t.correct, isNot(t.wrong));
    }
  });

  test('ThemeData modul Quran mendaftarkan token semantik', () {
    final light = QuranTokens.themeData(false);
    final dark = QuranTokens.themeData(true);
    expect(light.extension<QuranSemanticColors>(), isNotNull);
    expect(dark.extension<QuranSemanticColors>(), isNotNull);
    expect(dark.brightness, Brightness.dark);
    expect(
      light.extension<QuranSemanticColors>()!.correct,
      QuranTokens.correct(false),
    );
  });
}
