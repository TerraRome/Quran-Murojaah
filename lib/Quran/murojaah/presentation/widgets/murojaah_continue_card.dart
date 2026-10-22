import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';

/// Tombol besar "Lanjutkan murojaah" di bawah header progres.
///
/// Presentasional: surah, riwayat, dan aksi ditentukan halaman induk.
///
/// Warna tombol memakai `activeBg` + garis tepi, bukan `brandColor` sebagai
/// latar: teks putih di atas brand gelap (#A44AFF) hanya 4.20:1 — di bawah
/// ambang 4.5:1. Dengan `activeBg`, teks `inkColor` mencapai 14.11:1 (terang)
/// dan 12.23:1 (gelap). Brand tetap hadir lewat ikon dan judul kartu.
class MurojaahContinueCard extends StatelessWidget {
  const MurojaahContinueCard({
    super.key,
    required this.surahNumber,
    required this.surahName,
    required this.hasHistory,
    required this.onTap,
  });

  final int surahNumber;
  final String surahName;
  final bool hasHistory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final label = hasHistory
        ? 'Lanjutkan murojaah $surahName'
        : 'Mulai murojaah $surahName';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasHistory ? 'Terakhir kamu baca' : 'Belum ada riwayat',
            style: QuranTokens.poppins(
              QuranTokens.tsLastReadSub,
            ).copyWith(color: QuranTokens.textMuted(dark)),
          ),
          const SizedBox(height: 2),
          Text(
            'Surah $surahNumber · $surahName',
            style: QuranTokens.poppins(QuranTokens.tsSurahName).copyWith(
              color: QuranTokens.inkColor(dark),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: QuranTokens.activeBg(dark),
            borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
                  border: Border.all(color: QuranTokens.border(dark)),
                  boxShadow: QuranTokens.cardShadow(dark),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasHistory
                          ? Icons.play_circle_outline_rounded
                          : Icons.menu_book_outlined,
                      size: 22,
                      color: QuranTokens.brandColor(dark),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: QuranTokens.poppins(QuranTokens.tsSurahName)
                            .copyWith(
                              color: QuranTokens.inkColor(dark),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: QuranTokens.textMuted(dark),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasHistory
                ? 'Lanjut dari ayat terakhir.'
                : 'Mulai dari $surahName.',
            style: QuranTokens.poppins(
              QuranTokens.tsLastReadSub,
            ).copyWith(color: QuranTokens.textMuted(dark)),
          ),
        ],
      ),
    );
  }
}
