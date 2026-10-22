import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../heard_word.dart';

/// Sheet koreksi kata merah: kata yang seharusnya vs yang terdengar.
///
/// [heard] null berarti ASR tidak menghasilkan bunyi di posisi kata itu
/// (kata benar-benar dilewati), bukan sekadar "belum diproses".
Future<void> showReciteCorrectionSheet(
  BuildContext context, {
  required String expected,
  required String? heard,
  required bool dark,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: QuranTokens.surface(dark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => ReciteCorrectionSheet(
      expected: expected,
      heard: heard,
      dark: dark,
    ),
  );
}

class ReciteCorrectionSheet extends StatelessWidget {
  const ReciteCorrectionSheet({
    super.key,
    required this.expected,
    required this.heard,
    required this.dark,
  });

  final String expected;
  final String? heard;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    // Fonem mentah dirender sebagai potongan terpisah (penanda madd tanpa
    // bentuk sambung), jadi rapikan dulu — hanya untuk tampilan.
    final shown = heard == null ? '' : displayHeard(heard!);
    final missing = shown.isEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Koreksi kata',
              textAlign: TextAlign.center,
              style: QuranTokens.poppins(
                TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: QuranTokens.secondaryColor(dark),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SheetSide(
                    label: 'Seharusnya',
                    text: expected,
                    color: QuranTokens.successColor(dark),
                    size: 30,
                    dark: dark,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: Icon(
                    Icons.arrow_back,
                    size: 18,
                    color: QuranTokens.secondaryColor(dark)
                        .withValues(alpha: 0.6),
                  ),
                ),
                Expanded(
                  child: _SheetSide(
                    label: 'Terdengar',
                    text: missing ? 'tidak terdengar' : shown,
                    color: missing
                        ? QuranTokens.secondaryColor(dark)
                        : Colors.red.shade400,
                    size: missing ? 14 : 22,
                    dark: dark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSide extends StatelessWidget {
  const _SheetSide({
    required this.label,
    required this.text,
    required this.color,
    required this.size,
    required this.dark,
  });

  final String label;
  final String text;
  final Color color;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: QuranTokens.poppins(
            TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: QuranTokens.secondaryColor(dark),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: QuranTokens.amiri(
            TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }
}
