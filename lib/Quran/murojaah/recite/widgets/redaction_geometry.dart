import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// Jarak horizontal minimum (px) antara kotak redaksi dan penanda ayat, juga
/// antara dua kotak redaksi yang tidak bersambung.
const double kRedactionGap = 6;

/// Padding dalam kotak redaksi: garis kotak digambar di dalam batas kata,
/// sehingga stroke tidak pernah keluar dari kotak glyph.
const double kRedactionInset = 3;

/// Kotak satu kata beserta id globalnya.
class WordBox {
  const WordBox(this.wordId, this.rect);
  final int wordId;
  final Rect rect;
}

/// Geometri kotak redaksi untuk kata-kata tersembunyi.
///
/// Murni: tanpa widget, tanpa painter — bisa dites langsung.
///
/// Aturan:
/// 1. Kata berurutan pada baris yang sama digabung jadi satu batang.
/// 2. Batang tidak boleh menutupi [markerBoxes] (penanda/nomor ayat); batang
///    dipotong dengan jarak [kRedactionGap] di kedua sisi penanda.
/// 3. Tepi kotak diinset [kRedactionInset] dari kotak glyph, jadi stroke tetap
///    di dalam kata dan tidak menyentuh kata/penanda tetangga.
/// 4. Tinggi kotak tidak melebihi tinggi baris: inset vertikal dibatasi
///    seperempat tinggi glyph.
List<Rect> redactionBoxes({
  required List<WordBox> words,
  required List<Rect> markerBoxes,
  double gap = kRedactionGap,
  double inset = kRedactionInset,
}) {
  if (words.isEmpty) return const [];

  final sorted = [...words]..sort((a, b) {
      if ((a.rect.top - b.rect.top).abs() > 2) {
        return a.rect.top.compareTo(b.rect.top);
      }
      return a.rect.left.compareTo(b.rect.left);
    });

  // 1. Gabung kata berurutan per baris.
  final runs = <Rect>[];
  final runIds = <int>[];
  for (final word in sorted) {
    final merges = runs.isNotEmpty &&
        (word.wordId - runIds.last).abs() == 1 &&
        word.rect.top < runs.last.bottom - 2;
    if (merges) {
      runs[runs.length - 1] = runs.last.expandToInclude(word.rect);
      runIds[runIds.length - 1] = word.wordId;
    } else {
      runs.add(word.rect);
      runIds.add(word.wordId);
    }
  }

  // 2. Potong batang di sekitar penanda ayat, lalu inset.
  final out = <Rect>[];
  for (final run in runs) {
    for (final piece in _subtract(run, markerBoxes, gap)) {
      final box = _inset(piece, inset);
      if (box.width > 1) out.add(box);
    }
  }
  return out;
}

/// Buang bagian [rect] yang berjarak kurang dari [gap] dari [blockers].
///
/// Pemotongan hanya horizontal dan hanya untuk blocker yang satu baris;
/// hasilnya 0–2 potongan.
List<Rect> _subtract(Rect rect, List<Rect> blockers, double gap) {
  var pieces = <Rect>[rect];
  for (final b in blockers) {
    if (b.bottom <= rect.top || b.top >= rect.bottom) continue;
    final keepLeft = b.left - gap;
    final keepRight = b.right + gap;
    final next = <Rect>[];
    for (final p in pieces) {
      if (p.right <= keepLeft || p.left >= keepRight) {
        next.add(p);
        continue;
      }
      if (p.left < keepLeft) {
        next.add(Rect.fromLTRB(p.left, p.top, keepLeft, p.bottom));
      }
      if (p.right > keepRight) {
        next.add(Rect.fromLTRB(keepRight, p.top, p.right, p.bottom));
      }
    }
    pieces = next;
  }
  return pieces;
}

/// Inset kotak glyph jadi kotak gambar: tidak keluar batas kata dan tidak
/// melebihi tinggi baris.
Rect _inset(Rect rect, double inset) {
  final vertical = math.min(5.0, rect.height * 0.25);
  final horizontal = math.min(inset, rect.width / 2);
  return Rect.fromLTRB(
    rect.left + horizontal,
    rect.top + vertical,
    rect.right - horizontal,
    rect.bottom - vertical,
  );
}
