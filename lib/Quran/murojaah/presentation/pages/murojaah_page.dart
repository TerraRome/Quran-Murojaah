import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../application/quran_controller.dart';
import '../../../data/quran_tokens.dart';
import '../../../domain/entities/surah.dart';
import '../../../presentation/widgets/quran_theme_scope.dart';
import '../../../presentation/widgets/surah_card.dart';
import '../../progress/activity_entry.dart';
import '../../progress/progress_controller.dart';
import '../../progress/progress_service.dart';
import '../widgets/murojaah_continue_card.dart';
import '../widgets/murojaah_progress_header.dart';

/// Halaman tab Murojaah (Milestone 2).
///
/// Menampilkan daftar surah sebagai pintu masuk renderer mushaf. Tap surah →
/// halaman `MushafRendererPage`. Pilih surat & alur mulai dirombak pada
/// Milestone 3 (state). Belum ada speech recognition.
class MurojaahPage extends StatefulWidget {
  const MurojaahPage({
    super.key,
    required this.controller,
    required this.progress,
  });

  final QuranController controller;
  final MurojaahProgressController progress;

  @override
  State<MurojaahPage> createState() => _MurojaahPageState();
}

class _MurojaahPageState extends State<MurojaahPage> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.surahs.isEmpty) {
      widget.controller.load();
    }
    if (!widget.progress.isLoaded) {
      widget.progress.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return ValueListenableBuilder<QuranState>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        return SliverSafeArea(
          top: false,
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Murojaah',
                        style: QuranTokens.poppins(
                          QuranTokens.tsSurahName,
                        ).copyWith(color: QuranTokens.brandColor(dark)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pilih surat untuk membuka mushaf.',
                        style: QuranTokens.poppins(
                          QuranTokens.tsVerseTranslation,
                        ).copyWith(color: QuranTokens.secondaryColor(dark)),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: MurojaahProgressHeader(progress: widget.progress),
              ),
              SliverToBoxAdapter(
                child: ListenableBuilder(
                  listenable: widget.progress,
                  builder: (context, _) => _continueCard(context, state.surahs),
                ),
              ),
              ..._buildList(state, dark),
            ],
          ),
        );
      },
    );
  }

  /// Kartu "Lanjutkan": surah terakhir yang tercatat, atau surah 1 saat log
  /// kosong. Tidak dirender bila nama surah belum tersedia — lebih baik tidak
  /// ada kartu daripada nama kosong.
  Widget _continueCard(BuildContext context, List<Surah> surahs) {
    final last = ProgressService(
      widget.progress.entries,
    ).lastEntryOf(ActivityType.murojaah);
    final surahNumber = last?.surahNumber ?? 1;
    final match = surahs.where((s) => s.number == surahNumber);
    if (match.isEmpty) return const SizedBox.shrink();
    final surah = match.first;

    return MurojaahContinueCard(
      surahNumber: surahNumber,
      surahName: surah.transliteration,
      hasHistory: last != null,
      onTap: () => context.push('/home/quran/murojaah/surah/$surahNumber'),
    );
  }

  List<Widget> _buildList(QuranState state, bool dark) {
    if (state.isLoading) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    final surahs = state.surahs;
    if (surahs.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              'Gagal memuat daftar surah',
              style: QuranTokens.poppins(
                QuranTokens.tsSurahName,
              ).copyWith(color: QuranTokens.secondaryColor(dark)),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        sliver: SliverList.separated(
          itemCount: surahs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final surah = surahs[index];
            return SurahCard(
              surah: surah,
              onTap: () =>
                  context.push('/home/quran/murojaah/surah/${surah.number}'),
            );
          },
        ),
      ),
    ];
  }
}
