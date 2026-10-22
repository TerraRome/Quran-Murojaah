import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:recite_quran/recite_quran.dart';

import '../../../data/quran_tokens.dart';
import '../../../presentation/widgets/quran_theme_scope.dart';

/// Angka Arab-Indik (0..9 → ٠١٢٣٤٥٦٧٨٩).
String arabicIndic(int value) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return value.toString().split('').map((c) => digits[int.parse(c)]).join();
}

/// Renderer mushaf untuk Murojaah berbasis `recite_quran`.
///
/// Seluruh surah dirender sebagai satu aliran teks RTL (bukan daftar ayat).
/// Ayat yang belum terbuka tetap menempati ruang aslinya: teksnya dicat
/// transparan lalu ditutup blok redaksi yang digambar di atasnya. Saat ayat
/// dibuka, blok memudar — tata letak tidak pernah bergeser.
class ReciteMushaf extends StatefulWidget {
  const ReciteMushaf({
    super.key,
    required this.verses,
    required this.revealedCount,
    this.lastMatchedWord,
    this.retryVerseIndex,
  });

  final List<QuranVerse> verses;

  /// Jumlah ayat pertama yang sudah diterima (revealed).
  final int revealedCount;

  /// Indeks kata global (0-based) yang baru cocok — diberi highlight halus.
  final int? lastMatchedWord;

  /// Ayat yang sedang perlu diulang (state merah), null bila tidak ada.
  final int? retryVerseIndex;

  @override
  State<ReciteMushaf> createState() => _ReciteMushafState();
}

class _ReciteMushafState extends State<ReciteMushaf>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );

  /// Ayat yang bloknya sedang memudar (baru dibuka).
  int? _fading;
  double _lastScrollTarget = -1;

  @override
  void didUpdateWidget(covariant ReciteMushaf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revealedCount > oldWidget.revealedCount) {
      _fading = widget.revealedCount - 1;
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToActive(_MushafLayout layout) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final boxes = layout.verseBoxes[widget.revealedCount];
      if (boxes == null || boxes.isEmpty) return;
      final top = boxes.map((b) => b.top).reduce(math.min);
      final target = (top - 24).clamp(0.0, double.infinity);
      if ((target - _lastScrollTarget).abs() < 4) return;
      _lastScrollTarget = target;
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    final fontSize =
        (QuranThemeScope.arabicFontSizeOf(context) * 1.55).clamp(21.0, 40.0);
    final base = QuranTokens.amiri(
      TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        height: 1.95,
        color: QuranTokens.arabicNameColor(dark),
      ),
    );
    final doc = _MushafDoc.build(
      verses: widget.verses,
      base: base,
      lastMatchedWord: widget.lastMatchedWord,
      revealedCount: widget.revealedCount,
      dark: dark,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = doc.layout(constraints.maxWidth);
        _scrollToActive(layout);
        return SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 28),
          child: SizedBox(
            width: constraints.maxWidth,
            child: Stack(
              children: [
                RichText(
                  text: TextSpan(children: doc.spans, style: base),
                  textDirection: TextDirection.rtl,
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _fade,
                      builder: (context, _) => CustomPaint(
                        painter: _RedactionPainter(
                          layout: layout,
                          revealedCount: widget.revealedCount,
                          fading: _fading,
                          fade: Curves.easeOut.transform(_fade.value),
                          retryVerseIndex: widget.retryVerseIndex,
                          blockColor: QuranTokens.inkColor(dark)
                              .withValues(alpha: dark ? 0.24 : 0.15),
                          retryColor:
                              Colors.red.shade400.withValues(alpha: 0.30),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dokumen mushaf: rangkaian span (kata + penanda ayat) beserta offset tiap
/// ayat untuk menghitung kotak redaksi.
class _MushafDoc {
  _MushafDoc._(this.spans, this.verseStarts, this.verseEnds, this.style);

  final List<InlineSpan> spans;
  final List<int> verseStarts;
  final List<int> verseEnds;
  final TextStyle style;

  double? _width;
  _MushafLayout? _layout;

  factory _MushafDoc.build({
    required List<QuranVerse> verses,
    required TextStyle base,
    required int? lastMatchedWord,
    required int revealedCount,
    required bool dark,
  }) {
    final spans = <InlineSpan>[];
    final starts = <int>[];
    final ends = <int>[];
    final highlight = QuranTokens.brandColor(dark).withValues(alpha: 0.16);
    var offset = 0;
    var wordId = 0;

    for (var v = 0; v < verses.length; v++) {
      final verse = verses[v];
      // Ayat yang belum terbuka: teks transparan supaya tidak terbaca.
      final hidden = v >= revealedCount;
      starts.add(offset);
      final words = verse.uthmaniWords.isNotEmpty
          ? verse.uthmaniWords
          : verse.textUthmani.split(RegExp(r'\s+'));
      for (var w = 0; w < words.length; w++) {
        final matched = wordId == lastMatchedWord;
        spans.add(
          TextSpan(
            text: words[w],
            style: hidden
                ? const TextStyle(color: Colors.transparent)
                : matched
                    ? TextStyle(backgroundColor: highlight)
                    : null,
          ),
        );
        offset += words[w].length;
        wordId++;
        if (w < words.length - 1) {
          spans.add(const TextSpan(text: ' '));
          offset += 1;
        }
      }
      ends.add(offset);
      // Nomor ayat tetap terlihat walau teksnya tersembunyi.
      final marker = ' ۝${arabicIndic(verse.ayah)} ';
      spans.add(TextSpan(text: marker));
      offset += marker.length;
    }

    return _MushafDoc._(spans, starts, ends, base);
  }

  /// Kotak tiap ayat pada lebar tertentu (di-cache per lebar).
  _MushafLayout layout(double maxWidth) {
    if (_layout != null && _width == maxWidth) return _layout!;
    final painter = TextPainter(
      text: TextSpan(children: spans, style: style),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: maxWidth);
    final boxes = <int, List<Rect>>{};
    for (var i = 0; i < verseStarts.length; i++) {
      boxes[i] = [
        for (final b in painter.getBoxesForSelection(
          TextSelection(baseOffset: verseStarts[i], extentOffset: verseEnds[i]),
        ))
          Rect.fromLTRB(b.left, b.top, b.right, b.bottom),
      ];
    }
    _width = maxWidth;
    return _layout = _MushafLayout(boxes);
  }
}

class _MushafLayout {
  const _MushafLayout(this.verseBoxes);

  final Map<int, List<Rect>> verseBoxes;
}

/// Menutup ayat yang belum terbuka dengan blok solid; ayat yang baru terbuka
/// memudar lewat [fade].
class _RedactionPainter extends CustomPainter {
  _RedactionPainter({
    required this.layout,
    required this.revealedCount,
    required this.fading,
    required this.fade,
    required this.retryVerseIndex,
    required this.blockColor,
    required this.retryColor,
  });

  final _MushafLayout layout;
  final int revealedCount;
  final int? fading;
  final double fade;
  final int? retryVerseIndex;
  final Color blockColor;
  final Color retryColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in layout.verseBoxes.entries) {
      final index = entry.key;
      var color = index == retryVerseIndex ? retryColor : blockColor;
      if (index >= revealedCount) {
        // Masih tertutup penuh.
      } else if (index == fading) {
        color = color.withValues(alpha: color.a * (1 - fade));
      } else {
        continue;
      }
      final paint = Paint()..color = color;
      for (final rect in entry.value) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              rect.left - 1,
              rect.top + 5,
              rect.right + 1,
              rect.bottom - 5,
            ),
            const Radius.circular(2.5),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RedactionPainter old) =>
      old.layout != layout ||
      old.revealedCount != revealedCount ||
      old.fading != fading ||
      old.fade != fade ||
      old.retryVerseIndex != retryVerseIndex ||
      old.blockColor != blockColor ||
      old.retryColor != retryColor;
}
