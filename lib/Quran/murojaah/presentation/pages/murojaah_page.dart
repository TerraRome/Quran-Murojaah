import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../application/quran_controller.dart';
import '../../../data/quran_tokens.dart';
import '../../../presentation/widgets/quran_theme_scope.dart';
import '../../../presentation/widgets/surah_card.dart';

/// Halaman tab Murojaah (Milestone 2).
///
/// Menampilkan daftar surah sebagai pintu masuk renderer mushaf. Tap surah →
/// halaman `MushafRendererPage`. Pilih surat & alur mulai dirombak pada
/// Milestone 3 (state). Belum ada speech recognition.
class MurojaahPage extends StatefulWidget {
  const MurojaahPage({super.key, required this.controller});

  final QuranController controller;

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
                        style: QuranTokens.poppins(QuranTokens.tsSurahName)
                            .copyWith(color: QuranTokens.brandColor(dark)),
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
              if (kDebugMode)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.mic),
                      label: const Text('[DEV] Audio Capture POC'),
                      onPressed: () => context.push(
                        '/home/quran/murojaah/audio-capture-poc',
                      ),
                    ),
                  ),
                ),
              if (kDebugMode)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.graphic_eq),
                      label: const Text('[DEV] VAD POC'),
                      onPressed: () => context.push(
                        '/home/quran/murojaah/vad-poc',
                      ),
                    ),
                  ),
                ),
              ..._buildList(state, dark),
            ],
          ),
        );
      },
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
              style: QuranTokens.poppins(QuranTokens.tsSurahName)
                  .copyWith(color: QuranTokens.secondaryColor(dark)),
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
              onTap: () => context.push(
                '/home/quran/murojaah/surah/${surah.number}',
              ),
            );
          },
        ),
      ),
    ];
  }
}