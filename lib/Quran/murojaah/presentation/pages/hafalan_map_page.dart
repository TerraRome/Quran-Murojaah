import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../application/quran_controller.dart';
import '../../../data/quran_tokens.dart';
import '../../../domain/entities/surah.dart';
import '../../../presentation/widgets/quran_status_bar.dart';
import '../../../presentation/widgets/quran_theme_scope.dart';
import '../../../presentation/widgets/quran_top_bar.dart';
import '../../progress/hafalan_map.dart';
import '../../progress/progress_controller.dart';

/// Peta hafalan 114 surah.
///
/// Angka berasal dari satu [HafalanMap] yang sudah dihitung controller sekali
/// per muat/perubahan log; setiap baris hanya membaca hasil cache. Status
/// selalu ikon + teks, jadi terbaca tanpa membedakan warna.
class HafalanMapPage extends StatelessWidget {
  const HafalanMapPage({
    super.key,
    required this.controller,
    required this.progress,
  });

  final QuranController controller;
  final MurojaahProgressController progress;

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return QuranStatusBar(
      dark: dark,
      child: Scaffold(
        backgroundColor: QuranTokens.background(dark),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              QuranTopBar(
                title: 'Peta Hafalan',
                titleColor: QuranTokens.brandColor(dark),
                leading: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  color: QuranTokens.inkColor(dark),
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: Listenable.merge([controller, progress]),
                  builder: (context, _) {
                    // Satu peta untuk seluruh halaman, bukan satu pindaian per
                    // baris.
                    final map = progress.hafalan;
                    final surahs = controller.surahs;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      children: [
                        _Legend(dark: dark, map: map),
                        const SizedBox(height: 12),
                        for (
                          var number = 1;
                          number <= HafalanMap.surahCount;
                          number++
                        )
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _SurahRow(
                              dark: dark,
                              hafalan: map.of(number),
                              surah: _surahOf(surahs, number),
                              onTap: () => context.push(
                                '/home/quran/murojaah/surah/$number',
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Surah? _surahOf(List<Surah> surahs, int number) {
    for (final surah in surahs) {
      if (surah.number == number) return surah;
    }
    return null;
  }
}

/// Ringkasan jumlah surah per status — pengganti warna sebagai pembeda utama.
class _Legend extends StatelessWidget {
  const _Legend({required this.dark, required this.map});

  final bool dark;
  final HafalanMap map;

  @override
  Widget build(BuildContext context) {
    final style = QuranTokens.poppins(
      QuranTokens.tsLastReadSub,
    ).copyWith(color: QuranTokens.secondaryColor(dark));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QuranTokens.surfaceAlt(dark),
        border: Border.all(color: QuranTokens.border(dark)),
        borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hafalan dari sesi murojaah yang tercatat.', style: style),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _LegendItem(
                dark: dark,
                status: HafalanStatus.lancar,
                count: map.lancarCount,
              ),
              _LegendItem(
                dark: dark,
                status: HafalanStatus.sedang,
                count: map.sedangCount,
              ),
              _LegendItem(
                dark: dark,
                status: HafalanStatus.belumMulai,
                count: map.belumMulaiCount,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.dark,
    required this.status,
    required this.count,
  });

  final bool dark;
  final HafalanStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(dark, status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_statusIcon(status), size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${status.label} $count',
            style: QuranTokens.poppins(
              QuranTokens.tsLastReadSub,
            ).copyWith(color: QuranTokens.inkColor(dark)),
          ),
        ),
      ],
    );
  }
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({
    required this.dark,
    required this.hafalan,
    required this.surah,
    required this.onTap,
  });

  final bool dark;
  final HafalanSurah hafalan;
  final Surah? surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = surah?.transliteration ?? 'Surah ${hafalan.surahNumber}';
    final detail = hafalan.totalVerses <= 0
        ? '${hafalan.versesCovered} ayat tercatat'
        : '${hafalan.versesCovered} dari ${hafalan.totalVerses} ayat';

    return Material(
      color: QuranTokens.surfaceAlt(dark),
      borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: QuranTokens.border(dark)),
            borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${hafalan.surahNumber}',
                  style: QuranTokens.poppins(
                    QuranTokens.tsVerseNumber,
                  ).copyWith(color: QuranTokens.secondaryColor(dark)),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: QuranTokens.poppins(
                        QuranTokens.tsSurahName,
                      ).copyWith(color: QuranTokens.inkColor(dark)),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: QuranTokens.poppins(
                        QuranTokens.tsVerseNumber,
                      ).copyWith(color: QuranTokens.secondaryColor(dark)),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          _statusIcon(hafalan.status),
                          size: 18,
                          color: _statusColor(dark, hafalan.status),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            hafalan.status.label,
                            style: QuranTokens.poppins(
                              QuranTokens.tsLastReadSub,
                            ).copyWith(color: QuranTokens.inkColor(dark)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _statusIcon(HafalanStatus status) => switch (status) {
  HafalanStatus.belumMulai => Icons.radio_button_unchecked,
  HafalanStatus.sedang => Icons.timelapse_rounded,
  HafalanStatus.lancar => Icons.check_circle_rounded,
};

/// Ikon sudah membedakan status; warna hanya penguat.
Color _statusColor(bool dark, HafalanStatus status) => switch (status) {
  HafalanStatus.belumMulai => QuranTokens.secondaryColor(dark),
  HafalanStatus.sedang => QuranTokens.brandColor(dark),
  HafalanStatus.lancar => QuranTokens.correct(dark),
};
