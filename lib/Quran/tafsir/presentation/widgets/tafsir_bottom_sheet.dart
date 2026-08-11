import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../../domain/entities/verse.dart';
import '../../../presentation/widgets/quran_theme_scope.dart';
import '../../application/tafsir_controller.dart';

/// Bottom sheet tafsir — menampilkan penjelasan ayat dari API equran.id.
///
/// Fitur:
/// - Teks Arab ayat di atas teks tafsir
/// - Navigasi prev/next ayat tanpa tutup sheet
/// - Loading shimmer + error state
/// - Drag handle untuk dismiss
class TafsirBottomSheet extends StatelessWidget {
  const TafsirBottomSheet({
    super.key,
    required this.controller,
    required this.verses,
    required this.surahNumber,
    required this.totalAyat,
  });

  final TafsirController controller;

  /// List ayat surah untuk tampilkan teks Arab per ayat aktif.
  final List<Verse> verses;
  final int surahNumber;
  final int totalAyat;

  static Future<void> show({
    required BuildContext context,
    required TafsirController controller,
    required List<Verse> verses,
    required int surahNumber,
    required int totalAyat,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TafsirBottomSheet(
        controller: controller,
        verses: verses,
        surahNumber: surahNumber,
        totalAyat: totalAyat,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: QuranTokens.background(dark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: QuranTokens.secondaryColor(dark).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Header + close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ValueListenableBuilder<TafsirState>(
                valueListenable: controller,
                builder: (_, state, __) {
                  final ayat = state is TafsirLoaded ? state.activeAyat : 0;
                  return Row(
                    children: [
                      Text(
                        ayat > 0 ? 'Tafsir Ayat $ayat' : 'Tafsir',
                        style: QuranTokens.poppins(
                          const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ).copyWith(color: QuranTokens.inkColor(dark)),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: QuranTokens.secondaryColor(dark),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            Divider(height: 1, color: QuranTokens.listDivider(dark)),

            // Content
            Expanded(
              child: ValueListenableBuilder<TafsirState>(
                valueListenable: controller,
                builder: (_, state, __) {
                  return switch (state) {
                    TafsirIdle() => const SizedBox.shrink(),
                    TafsirLoading() => _LoadingView(dark: dark),
                    TafsirError(:final message) =>
                      _ErrorView(message: message, dark: dark),
                    TafsirLoaded() => _ContentView(
                        state: state,
                        verses: verses,
                        surahNumber: surahNumber,
                        totalAyat: totalAyat,
                        controller: controller,
                        scrollController: scrollController,
                        dark: dark,
                      ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentView extends StatelessWidget {
  const _ContentView({
    required this.state,
    required this.verses,
    required this.surahNumber,
    required this.totalAyat,
    required this.controller,
    required this.scrollController,
    required this.dark,
  });

  final TafsirLoaded state;
  final List<Verse> verses;
  final int surahNumber;
  final int totalAyat;
  final TafsirController controller;
  final ScrollController scrollController;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final tafsir = state.activeTafsir;
    final verse = verses.where((v) => v.numberInSurah == state.activeAyat).firstOrNull;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Teks Arab ayat
                if (verse != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: QuranTokens.verseBg(dark),
                      borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
                    ),
                    child: Text(
                      verse.displayArabic(surahNumber),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: QuranTokens.amiri(
                        const TextStyle(fontSize: 22, height: 1.9),
                      ).copyWith(color: QuranTokens.inkColor(dark)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Teks tafsir
                if (tafsir != null)
                  Text(
                    tafsir.teks,
                    style: QuranTokens.poppins(
                      const TextStyle(fontSize: 14, height: 1.7),
                    ).copyWith(color: QuranTokens.secondaryColor(dark)),
                  )
                else
                  Center(
                    child: Text(
                      'Tafsir untuk ayat ini tidak tersedia.',
                      style: QuranTokens.poppins(
                        const TextStyle(fontSize: 14),
                      ).copyWith(color: QuranTokens.secondaryColor(dark)),
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Navigasi prev/next
        Divider(height: 1, color: QuranTokens.listDivider(dark)),
        _NavigationBar(
          state: state,
          totalAyat: totalAyat,
          controller: controller,
          dark: dark,
        ),
      ],
    );
  }
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.state,
    required this.totalAyat,
    required this.controller,
    required this.dark,
  });

  final TafsirLoaded state;
  final int totalAyat;
  final TafsirController controller;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final hasPrev = state.activeAyat > 1;
    final hasNext = state.activeAyat < totalAyat;
    final brand = QuranTokens.brandColor(dark);
    final disabled = QuranTokens.secondaryColor(dark).withValues(alpha: 0.4);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Prev
            Expanded(
              child: TextButton.icon(
                onPressed: hasPrev ? controller.prevAyat : null,
                icon: Icon(Icons.arrow_back_ios_new, size: 14,
                    color: hasPrev ? brand : disabled),
                label: Text(
                  'Ayat Sebelumnya',
                  style: QuranTokens.poppins(
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ).copyWith(color: hasPrev ? brand : disabled),
                ),
              ),
            ),

            // Nomor ayat
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: QuranTokens.verseBg(dark),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${state.activeAyat} / $totalAyat',
                style: QuranTokens.poppins(
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ).copyWith(color: QuranTokens.secondaryColor(dark)),
              ),
            ),

            // Next
            Expanded(
              child: TextButton.icon(
                onPressed: hasNext ? () => controller.nextAyat(totalAyat) : null,
                icon: Text(
                  'Ayat Berikutnya',
                  style: QuranTokens.poppins(
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ).copyWith(color: hasNext ? brand : disabled),
                ),
                label: Icon(Icons.arrow_forward_ios, size: 14,
                    color: hasNext ? brand : disabled),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          CircularProgressIndicator(
            color: QuranTokens.brandColor(dark),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat tafsir...',
            style: QuranTokens.poppins(const TextStyle(fontSize: 14))
                .copyWith(color: QuranTokens.secondaryColor(dark)),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.dark});
  final String message;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48,
              color: QuranTokens.secondaryColor(dark)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: QuranTokens.poppins(const TextStyle(fontSize: 14))
                .copyWith(color: QuranTokens.secondaryColor(dark)),
          ),
        ],
      ),
    );
  }
}
