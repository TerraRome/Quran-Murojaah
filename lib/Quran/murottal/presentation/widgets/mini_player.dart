import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../../presentation/widgets/quran_theme_scope.dart';
import '../../application/murottal_controller.dart';

/// Mini player global — bottom sheet persistent saat murottal berjalan.
///
/// Fitur:
/// - Nama surah + nomor ayat
/// - Seek bar dengan posisi waktu
/// - Kontrol: prev ayat, play/pause, next ayat
/// - Tombol close untuk stop audio
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.controller,
  });

  final MurottalController controller;

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return ValueListenableBuilder<MurottalState>(
      valueListenable: controller,
      builder: (context, state, _) {
        if (state is MurottalIdle) return const SizedBox.shrink();

        return _MiniPlayerContent(
          state: state,
          controller: controller,
          dark: dark,
        );
      },
    );
  }
}

class _MiniPlayerContent extends StatelessWidget {
  const _MiniPlayerContent({
    required this.state,
    required this.controller,
    required this.dark,
  });

  final MurottalState state;
  final MurottalController controller;
  final bool dark;

  bool get isPlaying => state is MurottalPlaying;
  bool get isLoading => state is MurottalLoading;

  String get surahName {
    return switch (state) {
      MurottalPlaying(:final surahName) => surahName,
      MurottalPaused(:final surahName) => surahName,
      MurottalLoading(:final surahNumber) => 'Surah $surahNumber',
      MurottalError() => '',
      MurottalIdle() => '',
    };
  }

  String get subtitle {
    return switch (state) {
      MurottalPlaying(:final currentAyat, :final totalAyat, :final isFullSurah) =>
        isFullSurah ? 'Full Surah' : 'Ayat $currentAyat / $totalAyat',
      MurottalPaused(:final currentAyat, :final totalAyat, :final isFullSurah) =>
        isFullSurah ? 'Full Surah' : 'Ayat $currentAyat / $totalAyat',
      MurottalLoading() => 'Memuat...',
      MurottalError(:final message) => message,
      MurottalIdle() => '',
    };
  }

  Duration get position {
    return switch (state) {
      MurottalPlaying(:final position) => position,
      MurottalPaused(:final position) => position,
      _ => Duration.zero,
    };
  }

  Duration get duration {
    return switch (state) {
      MurottalPlaying(:final duration) => duration,
      MurottalPaused(:final duration) => duration,
      _ => Duration.zero,
    };
  }

  bool get isFullSurah {
    return switch (state) {
      MurottalPlaying(:final isFullSurah) => isFullSurah,
      MurottalPaused(:final isFullSurah) => isFullSurah,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: QuranTokens.surface(dark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: info + close
              Row(
                children: [
                  // Ikon murottal
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [QuranTokens.gradientStart, QuranTokens.gradientEnd],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.headphones, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),

                  // Nama surah + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          surahName,
                          style: QuranTokens.poppins(
                            const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ).copyWith(color: QuranTokens.inkColor(dark)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle,
                          style: QuranTokens.poppins(
                            const TextStyle(fontSize: 12),
                          ).copyWith(color: QuranTokens.secondaryColor(dark)),
                        ),
                      ],
                    ),
                  ),

                  // Tombol close
                  IconButton(
                    onPressed: controller.stop,
                    icon: Icon(Icons.close,
                        color: QuranTokens.secondaryColor(dark), size: 20),
                  ),
                ],
              ),

              // Seek bar
              if (!isLoading && duration > Duration.zero) ...[
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: QuranTokens.brandColor(dark),
                    inactiveTrackColor: QuranTokens.listDivider(dark),
                    thumbColor: QuranTokens.brandColor(dark),
                    overlayColor: QuranTokens.brandColor(dark).withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: position.inMilliseconds
                        .clamp(0, duration.inMilliseconds)
                        .toDouble(),
                    max: duration.inMilliseconds.toDouble(),
                    onChanged: (v) =>
                        controller.seekTo(Duration(milliseconds: v.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: QuranTokens.poppins(const TextStyle(fontSize: 10))
                            .copyWith(color: QuranTokens.secondaryColor(dark)),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: QuranTokens.poppins(const TextStyle(fontSize: 10))
                            .copyWith(color: QuranTokens.secondaryColor(dark)),
                      ),
                    ],
                  ),
                ),
              ],

              // Kontrol play
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Prev ayat (hanya mode per-ayat)
                  if (!isFullSurah)
                    IconButton(
                      onPressed: isLoading ? null : controller.prevAyat,
                      icon: Icon(Icons.skip_previous_rounded,
                          color: QuranTokens.inkColor(dark), size: 28),
                    ),

                  // Play/Pause
                  if (isLoading)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: QuranTokens.brandColor(dark),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: isPlaying ? controller.pause : controller.resume,
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_filled_rounded,
                        color: QuranTokens.brandColor(dark),
                        size: 44,
                      ),
                    ),

                  // Next ayat (hanya mode per-ayat)
                  if (!isFullSurah)
                    IconButton(
                      onPressed: isLoading ? null : controller.nextAyat,
                      icon: Icon(Icons.skip_next_rounded,
                          color: QuranTokens.inkColor(dark), size: 28),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
