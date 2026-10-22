import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/quran_tokens.dart';
import '../../domain/entities/surah.dart';
import '../../murottal/application/download_controller.dart';
import '../../murottal/application/murottal_controller.dart';

/// Header kartu surah di halaman detail: kartu gradient solid ungu radius 20
/// dengan watermark mushaf di pojok kanan bawah, konten kolom tengah berisi
/// transliterasi, arti nama surah, garis pembatas, meta, basmalah SVG,
/// dan satu tombol aksi dinamis (download / putar / jeda / lanjutkan).
class SurahHeaderCard extends StatelessWidget {
  const SurahHeaderCard({
    super.key,
    required this.surah,
    this.murottalState,
    this.downloadState,
    this.onActionTap,
  });

  final Surah surah;

  /// State murottal saat ini — untuk menentukan label & ikon tombol.
  final MurottalState? murottalState;

  /// State download saat ini — untuk menentukan label & ikon tombol.
  final DownloadState? downloadState;

  /// Callback tunggal — dipanggil untuk semua aksi (download / play / pause / resume).
  final VoidCallback? onActionTap;

  bool get _isPlayingThisSurah {
    final state = murottalState;
    if (state == null) return false;
    return switch (state) {
      MurottalPlaying(:final surahNumber, :final isFullSurah) =>
        surahNumber == surah.number && isFullSurah,
      _ => false,
    };
  }

  bool get _isPausedThisSurah {
    final state = murottalState;
    if (state == null) return false;
    return switch (state) {
      MurottalPaused(:final surahNumber, :final isFullSurah) =>
        surahNumber == surah.number && isFullSurah,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [QuranTokens.gradientStart, QuranTokens.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Watermark mushaf
          Positioned(
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: 0.3,
              child: Image.asset(
                'assets/quran/mushaf.png',
                width: 160,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                Text(
                  surah.transliteration,
                  textAlign: TextAlign.center,
                  style: QuranTokens.poppins(QuranTokens.tsDetailTitle)
                      .copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  surah.translation,
                  textAlign: TextAlign.center,
                  style: QuranTokens.poppins(QuranTokens.tsDetailMeaning)
                      .copyWith(color: Colors.white),
                ),
                const SizedBox(height: QuranTokens.space7),
                FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: QuranTokens.space7),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: _MetaText(text: surah.revelationType.label),
                    ),
                    const SizedBox(width: 6),
                    const _Dot(),
                    const SizedBox(width: 6),
                    Flexible(
                      child: _MetaText(text: '${surah.totalVerses} Ayat'),
                    ),
                  ],
                ),
                const SizedBox(height: QuranTokens.space8),
                SvgPicture.asset(
                  'assets/quran/bismillah.svg',
                  width: 180,
                ),
                const SizedBox(height: 20),

                // Satu tombol aksi dinamis (download / putar / jeda / lanjutkan)
                if (onActionTap != null && downloadState != null)
                  _MurottalActionButton(
                    downloadState: downloadState!,
                    isPlaying: _isPlayingThisSurah,
                    isPaused: _isPausedThisSurah,
                    onTap: onActionTap!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu tombol aksi murottal dengan label & ikon dinamis:
/// - DownloadInProgress        → "Mengunduh X%" + spinner (tap = batalkan)
/// - DownloadCompleted + playing → "Jeda Murottal" + pause icon
/// - DownloadCompleted + paused  → "Lanjutkan Murottal" + play icon
/// - DownloadCompleted + idle    → "Putar Murottal" + play icon
/// - DownloadIdle/Error          → "Download Murottal" + download icon
class _MurottalActionButton extends StatelessWidget {
  const _MurottalActionButton({
    required this.downloadState,
    required this.isPlaying,
    required this.isPaused,
    required this.onTap,
  });

  final DownloadState downloadState;
  final bool isPlaying;
  final bool isPaused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Sedang mengunduh — spinner + persentase, tap = batalkan
    if (downloadState is DownloadInProgress) {
      final percent = (downloadState as DownloadInProgress).percent;
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(
                color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              value: percent != null ? percent / 100 : null,
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          label: Text(
            percent != null ? 'Mengunduh $percent%' : 'Mengunduh...',
            style: QuranTokens.poppins(
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ),
      );
    }

    // Sudah tersimpan — tombol play/pause/resume
    if (downloadState is DownloadCompleted) {
      final IconData icon;
      final String label;
      if (isPlaying) {
        icon = Icons.pause_rounded;
        label = 'Jeda Murottal';
      } else if (isPaused) {
        icon = Icons.play_arrow_rounded;
        label = 'Lanjutkan Murottal';
      } else {
        icon = Icons.play_arrow_rounded;
        label = 'Putar Murottal';
      }
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white, width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            style: QuranTokens.poppins(
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ),
      );
    }

    // Belum tersimpan (idle / error / checking) — tombol download
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        icon: const Icon(Icons.download_rounded, size: 20),
        label: Text(
          'Download Murottal',
          style: QuranTokens.poppins(
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: QuranTokens.poppins(QuranTokens.tsDetailMeta)
          .copyWith(color: Colors.white, letterSpacing: 0.8),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
