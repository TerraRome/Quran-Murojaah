import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../heard_word.dart';

/// Sheet koreksi kata merah: kata yang seharusnya, lalu — bila user ingin
/// tahu — apa yang terdengar.
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
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) =>
        ReciteCorrectionSheet(expected: expected, heard: heard, dark: dark),
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
    final muted = QuranTokens.textMuted(dark);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: QuranTokens.border(dark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 22,
                  color: QuranTokens.wrong(dark),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kata ini perlu diulang',
                    style: QuranTokens.poppins(
                      TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: QuranTokens.inkColor(dark),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: QuranTokens.background(dark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: QuranTokens.border(dark)),
              ),
              child: Column(
                children: [
                  Text(
                    'Seharusnya',
                    style: QuranTokens.poppins(
                      TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    expected,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: QuranTokens.amiri(
                      TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: QuranTokens.correct(dark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: QuranTokens.semantic(dark).activeBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    size: 20,
                    color: QuranTokens.brandColor(dark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      missing
                          ? 'Kata ini belum terbaca. Baca pelan-pelan, lalu ulangi ayat ini.'
                          : 'Dengarkan lagi bacaannya, lalu ulangi ayat ini pelan-pelan.',
                      style: QuranTokens.poppins(
                        TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: QuranTokens.inkColor(dark),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Apa yang terdengar bersifat opsional: tidak semua orang perlu
            // melihat tebakan mesin, dan tebakan itu bisa membingungkan.
            if (!missing)
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  iconColor: muted,
                  collapsedIconColor: muted,
                  title: Text(
                    'Lihat yang terdengar',
                    style: QuranTokens.poppins(
                      TextStyle(fontSize: 14, color: muted),
                    ),
                  ),
                  children: [
                    Text(
                      shown,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: QuranTokens.amiri(
                        TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: QuranTokens.wrong(dark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: muted,
                textStyle: QuranTokens.poppins(
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }
}
