import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../domain/entities/doa.dart';

/// Kartu doa untuk list. Menampilkan nama, grup, potongan Arab, dan ikon bookmark.
class DoaCard extends StatelessWidget {
  const DoaCard({
    super.key,
    required this.doa,
    required this.isBookmarked,
    required this.onTap,
    required this.onBookmarkTap,
    required this.dark,
  });

  final Doa doa;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmarkTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: QuranTokens.surface(dark),
            borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
          ),
          child: Row(
            children: [
              // Nomor / ikon doa
              _DoaNumberBadge(id: doa.id, dark: dark),
              const SizedBox(width: 14),
              // Konten utama
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doa.nama,
                      style: QuranTokens.poppins(
                        QuranTokens.tsSurahName,
                      ).copyWith(color: QuranTokens.inkColor(dark)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (doa.ar.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        doa.ar,
                        textDirection: TextDirection.rtl,
                        style: QuranTokens.amiri(
                          const TextStyle(fontSize: 16),
                        ).copyWith(color: QuranTokens.arabicNameColor(dark)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Bookmark
              GestureDetector(
                onTap: onBookmarkTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: isBookmarked
                        ? QuranTokens.brandColor(dark)
                        : QuranTokens.secondaryColor(dark),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoaNumberBadge extends StatelessWidget {
  const _DoaNumberBadge({required this.id, required this.dark});

  final int id;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [QuranTokens.gradientStart, QuranTokens.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        '$id',
        style: QuranTokens.poppins(
          // Badge ini selalu berlatar gradient gelap (bukan brandColor), jadi
          // putih tetap pilihan benar di kedua mode: 4.85:1 di stop terang.
          const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
