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
/// Kata yang belum diucapkan benar tetap menempati ruang aslinya: teksnya
/// dicat transparan lalu ditutup blok redaksi per kata. Kata yang sudah cocok
/// tampil hijau, kata yang salah tampil merah. Tata letak tidak pernah
/// bergeser.
class ReciteMushaf extends StatefulWidget {
  const ReciteMushaf({
    super.key,
    required this.verses,
    required this.matched,
    required this.missed,
    required this.activeVerse,
    this.peekWord,
    this.onWordTap,
  });

  final List<QuranVerse> verses;

  /// Indeks kata global (0-based) yang sudah diucapkan benar.
  final Set<int> matched;

  /// Indeks kata global yang ditandai salah / terlupa.
  final Set<int> missed;

  /// Ayat yang sedang dibaca — target auto-scroll.
  final int activeVerse;

  /// Kata yang sedang dibuka sementara (peek hint) — tampil tapi tidak dihitung.
  final int? peekWord;

  /// Dipanggil saat kata di mushaf disentuh (untuk sheet koreksi).
  final ValueChanged<int>? onWordTap;

  @override
  State<ReciteMushaf> createState() => _ReciteMushafState();
}

class _ReciteMushafState extends State<ReciteMushaf> {
  final ScrollController _scroll = ScrollController();
  double _lastScrollTarget = -1;

  /// Dokumen di-cache: dibangun ulang hanya saat state visual berubah.
  _MushafDoc? _doc;
  ({int matched, int missed, bool dark, double fontSize, int peek})? _docKey;

  _MushafDoc _document(TextStyle base, double fontSize, bool dark) {
    final key = (
      matched: Object.hashAll(widget.matched),
      missed: Object.hashAll(widget.missed),
      dark: dark,
      fontSize: fontSize,
      peek: widget.peekWord ?? -1,
    );
    if (_doc != null && _docKey == key) return _doc!;
    _docKey = key;
    return _doc = _MushafDoc.build(
      verses: widget.verses,
      base: base,
      matched: widget.matched,
      missed: widget.missed,
      peekWord: widget.peekWord,
      dark: dark,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToActive(_MushafLayout layout) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final boxes = layout.verseBoxes[widget.activeVerse];
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
    final fontSize = (QuranThemeScope.arabicFontSizeOf(context) * 1.55).clamp(
      21.0,
      40.0,
    );
    final base = QuranTokens.amiri(
      TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        height: 1.95,
        color: QuranTokens.arabicNameColor(dark),
      ),
    );
    final doc = _document(base, fontSize, dark);

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = doc.layout(constraints.maxWidth, fontSize);
        _scrollToActive(layout);
        return SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 28),
          // Surah pendek: isi tetap di tengah, bukan menumpuk di atas.
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: SizedBox(
                width: constraints.maxWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: widget.onWordTap == null
                      ? null
                      : (details) {
                          final id = layout.wordAt(details.localPosition);
                          if (id != null) widget.onWordTap!(id);
                        },
                  child: Stack(
                    children: [
                      // Sorot ayat yang sedang dinilai (di belakang teks).
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _ActiveVersePainter(
                              boxes:
                                  layout.verseBoxes[widget.activeVerse] ??
                                  const [],
                              color: QuranTokens.brandColor(dark),
                            ),
                          ),
                        ),
                      ),
                      // Lebar penuh supaya RichText dan overlay redaksi memakai
                      // sistem koordinat yang sama (RTL → rata kanan).
                      SizedBox(
                        width: constraints.maxWidth,
                        child: RichText(
                          text: TextSpan(children: doc.spans, style: base),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _RedactionPainter(
                              boxes: layout.hiddenBoxes,
                              color: QuranTokens.hidden(
                                dark,
                              ).withValues(alpha: dark ? 0.14 : 0.10),
                              dash: QuranTokens.hidden(
                                dark,
                              ).withValues(alpha: dark ? 0.90 : 0.75),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Dokumen mushaf: rangkaian span (kata + penanda ayat) beserta offset tiap
/// kata/ayat untuk menghitung kotak redaksi.
class _MushafDoc {
  _MushafDoc._(
    this.spans,
    this.wordRanges,
    this.verseStarts,
    this.verseEnds,
    this.hiddenWords,
    this.style,
  );

  final List<InlineSpan> spans;

  /// Rentang karakter tiap kata global (indeks = `wordId`).
  final List<(int, int)> wordRanges;
  final List<int> verseStarts;
  final List<int> verseEnds;

  /// `wordId` kata yang belum cocok — sumber blok redaksi.
  final List<int> hiddenWords;
  final TextStyle style;

  double? _width;
  _MushafLayout? _layout;

  factory _MushafDoc.build({
    required List<QuranVerse> verses,
    required TextStyle base,
    required Set<int> matched,
    required Set<int> missed,
    required bool dark,
    int? peekWord,
  }) {
    final spans = <InlineSpan>[];
    final ranges = <(int, int)>[];
    final starts = <int>[];
    final ends = <int>[];
    final hidden = <int>[];
    final green = QuranTokens.correct(dark);
    final red = QuranTokens.wrong(dark);
    final ink = QuranTokens.inkColor(dark);
    var offset = 0;
    var wordId = 0;

    for (var v = 0; v < verses.length; v++) {
      final verse = verses[v];
      starts.add(offset);
      final words = verse.uthmaniWords.isNotEmpty
          ? verse.uthmaniWords
          : verse.textUthmani.split(RegExp(r'\s+'));
      for (var w = 0; w < words.length; w++) {
        final word = words[w];
        // Kata yang belum diucapkan: transparan (ditutup blok redaksi) supaya
        // tidak terbaca tapi tata letak tetap. Kata "peek" tampil biasa tapi
        // tidak dihitung sebagai hafal.
        final Color color = matched.contains(wordId)
            ? green
            : missed.contains(wordId)
            ? red
            : wordId == peekWord
            ? ink
            : Colors.transparent;
        if (color == Colors.transparent) hidden.add(wordId);
        // Kata merah juga diberi garis bawah bergelombang: penanda bentuk, bukan
        // warna saja — tetap terbaca oleh pengguna buta warna.
        final isMissed = missed.contains(wordId);
        spans.add(
          TextSpan(
            text: word,
            style: TextStyle(
              color: color,
              decoration: isMissed
                  ? TextDecoration.underline
                  : TextDecoration.none,
              decorationStyle: isMissed ? TextDecorationStyle.wavy : null,
              decorationColor: red,
              decorationThickness: 2,
            ),
          ),
        );
        ranges.add((offset, offset + word.length));
        offset += word.length;
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

    return _MushafDoc._(spans, ranges, starts, ends, hidden, base);
  }

  /// Kotak tiap ayat + kotak kata tersembunyi pada lebar tertentu (cached).
  _MushafLayout layout(double maxWidth, double fontSize) {
    if (_layout != null && _width == maxWidth) return _layout!;
    final painter = TextPainter(
      text: TextSpan(children: spans, style: style),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: maxWidth);

    List<Rect> boxesOf(int start, int end) => [
      for (final b in painter.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      ))
        Rect.fromLTRB(b.left, b.top, b.right, b.bottom),
    ];

    final verseBoxes = <int, List<Rect>>{};
    for (var i = 0; i < verseStarts.length; i++) {
      verseBoxes[i] = boxesOf(verseStarts[i], verseEnds[i]);
    }

    final hiddenBoxes = _mergeRuns([
      for (final id in hiddenWords)
        for (final rect in boxesOf(wordRanges[id].$1, wordRanges[id].$2))
          (id: id, rect: rect),
    ]);

    _width = maxWidth;
    return _layout = _MushafLayout(
      verseBoxes,
      hiddenBoxes,
      painter,
      wordRanges,
    );
  }

  /// Gabungkan kotak per-kata menjadi satu batang per baris, tapi hanya untuk
  /// kata yang berurutan: blok tidak boleh menutupi kata yang sudah terbuka.
  static List<Rect> _mergeRuns(List<({int id, Rect rect})> boxes) {
    if (boxes.length < 2) return [for (final b in boxes) b.rect];
    final sorted = [...boxes]
      ..sort((a, b) {
        if ((a.rect.top - b.rect.top).abs() > 2) {
          return a.rect.top.compareTo(b.rect.top);
        }
        return a.rect.left.compareTo(b.rect.left);
      });
    final merged = <Rect>[];
    final ids = <int>[];
    for (final box in sorted) {
      if (merged.isNotEmpty &&
          (box.id - ids.last).abs() == 1 &&
          box.rect.top < merged.last.bottom - 2) {
        merged[merged.length - 1] = merged.last.expandToInclude(box.rect);
        ids[ids.length - 1] = box.id;
      } else {
        merged.add(box.rect);
        ids.add(box.id);
      }
    }
    return merged;
  }
}

class _MushafLayout {
  const _MushafLayout(
    this.verseBoxes,
    this.hiddenBoxes,
    this._painter,
    this._wordRanges,
  );

  final Map<int, List<Rect>> verseBoxes;
  final List<Rect> hiddenBoxes;
  final TextPainter _painter;
  final List<(int, int)> _wordRanges;

  /// `wordId` pada titik [point] (koordinat teks), atau null bila kena spasi.
  int? wordAt(Offset point) {
    final offset = _painter.getPositionForOffset(point).offset;
    var lo = 0;
    var hi = _wordRanges.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final (start, end) = _wordRanges[mid];
      if (offset < start) {
        hi = mid - 1;
      } else if (offset >= end) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }
    return null;
  }
}

/// Menutup kata yang belum terbuka: kotak bergaris putus-putus, tanpa blok
/// penuh — kata di bawahnya tetap terlihat samar sebagai bentuk, bukan
/// tertutup warna. Penanda bentuk (garis), bukan hanya warna.
///
/// Kotak tetap sama persis dengan kotak teks (hanya warna/guratan yang
/// berubah) supaya overlay dan hit-test tidak bergeser.
class _RedactionPainter extends CustomPainter {
  _RedactionPainter({
    required this.boxes,
    required this.color,
    required this.dash,
  });

  final List<Rect> boxes;
  final Color color;
  final Color dash;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = dash
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final rect in boxes) {
      final r = Rect.fromLTRB(
        rect.left - 1,
        rect.top + 5,
        rect.right + 1,
        rect.bottom - 5,
      );
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
      // Isi sangat tipis: cukup memisahkan dari latar, tidak menutupi bentuk
      // kata. Garis putus-putus yang menyatakan "di sini ada kata".
      canvas.drawRRect(rr, fill);
      _dashPath(canvas, Path()..addRRect(rr), stroke);
    }
  }

  /// Garis putus-putus mengikuti keliling kotak.
  void _dashPath(Canvas canvas, Path path, Paint paint) {
    const on = 5.0;
    const off = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = math.min(d + on, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + off;
      }
    }
  }

  @override
  bool shouldRepaint(_RedactionPainter old) =>
      old.boxes != boxes || old.color != color || old.dash != dash;
}

/// Latar lembut + batang penanda untuk ayat yang sedang dinilai.
class _ActiveVersePainter extends CustomPainter {
  _ActiveVersePainter({required this.boxes, required this.color});

  final List<Rect> boxes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (boxes.isEmpty) return;
    var r = boxes.first;
    for (final b in boxes.skip(1)) {
      r = r.expandToInclude(b);
    }
    final rect = Rect.fromLTRB(
      r.left - 10,
      r.top - 2,
      r.right + 10,
      r.bottom + 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()..color = color.withValues(alpha: 0.07),
    );
    // Batang di sisi kanan (awal bacaan pada teks RTL): penanda bentuk.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          rect.right - 3,
          rect.top + 6,
          rect.right,
          rect.bottom - 6,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = color.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_ActiveVersePainter old) =>
      old.boxes != boxes || old.color != color;
}
