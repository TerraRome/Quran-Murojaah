import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../../domain/entities/surah.dart';
import '../../../presentation/widgets/quran_theme_scope.dart';
import '../../application/murojaah_controller.dart';

/// Ubah angka latin menjadi angka Arab-Indik (0..9 → ٠١٢٣٤٥٦٧٨٩).
String arabicIndic(int value) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return value
      .toString()
      .split('')
      .map((c) => digits[int.parse(c)])
      .join();
}

/// Renderer mushaf (Milestone 2) + auto-scroll ke ayat aktif (Milestone 3).
///
/// Seluruh surat dirender sebagai **satu aliran teks RTL** menyerupai mushaf
/// asli (bukan daftar ayat). Setiap ayat diakhiri penanda `۝<nomor>` yang
/// selalu terlihat. Ayat yang belum ter-reveal tetap menempati ruang aslinya
/// (tata letak stabil) tetapi teksnya dicat dengan warna background sehingga
/// tampak transparan tanpa menggeser ayat lain.
///
/// Widget ini menangani sendiri scroll (SingleChildScrollView) dan otomatis
/// menggulir ke ayat aktif setiap ayat aktif berubah (auto-scroll).
class MurojaahMushaf extends StatefulWidget {
  const MurojaahMushaf({
    super.key,
    required this.surah,
    required this.controller,
    required this.dark,
  });

  final Surah surah;

  /// Pemegang status reveal & ayat aktif.
  final MurojaahController controller;

  final bool dark;

  @override
  State<MurojaahMushaf> createState() => _MurojaahMushafState();
}

class _MurojaahMushafState extends State<MurojaahMushaf> {
  final ScrollController _scroll = ScrollController();

  double? _lastTarget;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Bangun spans (teks ayat + penanda `۝<nomor>`) dan catat rentang offset
  /// teks ayat. Ayat tersembunyi dicat dengan warna latar.
  List<InlineSpan> _buildSpans(
    TextStyle baseStyle,
    Color hiddenColor, {
    List<(int, int)>? verseRanges,
  }) {
    final spans = <InlineSpan>[];
    var offset = 0;
    for (var i = 0; i < widget.surah.verses.length; i++) {
      final text = widget.surah.verses[i].displayArabic(widget.surah.number);
      final start = offset;
      offset += text.length;
      if (verseRanges != null) verseRanges.add((start, offset));
      final visible = widget.controller.isRevealed(i);
      spans.add(
        TextSpan(
          text: text,
          style: visible ? null : baseStyle.copyWith(color: hiddenColor),
        ),
      );
      final marker = ' ۝${arabicIndic(i + 1)} ';
      spans.add(TextSpan(text: marker));
      offset += marker.length;
    }
    return spans;
  }

  void _scheduleAutoScroll({
    required int active,
    required List<(int, int)> verseRanges,
    required List<InlineSpan> spans,
    required TextStyle baseStyle,
    required double maxWidth,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final (start, end) = verseRanges[active - 1];
      if (end <= start) return;
      final tp = TextPainter(
        text: TextSpan(children: spans, style: baseStyle),
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: maxWidth);
      final boxes = tp.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      );
      if (boxes.isEmpty) return;
      final top = boxes.map((b) => b.toRect().top).reduce(math.min);
      final target = (top - 16).clamp(0.0, double.infinity);
      if (_lastTarget != target) {
        _lastTarget = target;
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final fontSize =
        (QuranThemeScope.arabicFontSizeOf(context) * 1.6).clamp(22.0, 42.0);
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.9,
      color: QuranTokens.arabicNameColor(dark),
    );
    final hiddenColor = QuranTokens.background(dark);

    return ValueListenableBuilder<MurojaahState>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        final verseRanges = <(int, int)>[];
        final spans = _buildSpans(baseStyle, hiddenColor, verseRanges: verseRanges);
        final active = state.activeVerse;
        return LayoutBuilder(
          builder: (context, constraints) {
            if (active != null) {
              _scheduleAutoScroll(
                active: active,
                verseRanges: verseRanges,
                spans: spans,
                baseStyle: baseStyle,
                maxWidth: constraints.maxWidth,
              );
            }
            return SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
              child: SizedBox(
                width: constraints.maxWidth,
                child: RichText(
                  text: TextSpan(children: spans, style: baseStyle),
                  textDirection: TextDirection.rtl,
                ),
              ),
            );
          },
        );
      },
    );
  }
}