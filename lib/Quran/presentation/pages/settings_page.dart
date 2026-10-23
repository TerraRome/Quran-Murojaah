import 'package:flutter/material.dart';

import '../../application/quran_dependencies.dart';
import '../../data/quran_tokens.dart';
import '../../murojaah/presentation/widgets/backup_settings_section.dart';
import '../../murojaah/presentation/widgets/reminder_settings_section.dart';
import '../widgets/quran_status_bar.dart';
import '../widgets/quran_theme_scope.dart';
import '../widgets/quran_top_bar.dart';

/// Halaman Pengaturan: ukuran font, pengingat harian, dan cadangan data.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    final controller = QuranThemeScope.of(context);
    return QuranStatusBar(
      dark: dark,
      child: Scaffold(
        backgroundColor: QuranTokens.background(dark),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              QuranTopBar(
                title: 'Pengaturan',
                titleColor: QuranTokens.brandColor(dark),
                leading: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  color: QuranTokens.inkColor(dark),
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    children: [
                      _SectionTitle(dark: dark, title: 'Ukuran Teks Arab'),
                      const SizedBox(height: 8),
                      _FontSizeSlider(
                        dark: dark,
                        value: controller.arabicFontSize,
                        min: 14,
                        max: 36,
                        onChanged: (v) =>
                            QuranThemeScope.setArabicFontSize(context, v),
                      ),
                      const SizedBox(height: 24),
                      _SectionTitle(
                        dark: dark,
                        title: 'Ukuran Teks Terjemahan',
                      ),
                      const SizedBox(height: 8),
                      _FontSizeSlider(
                        dark: dark,
                        value: controller.translationFontSize,
                        min: 12,
                        max: 28,
                        onChanged: (v) =>
                            QuranThemeScope.setTranslationFontSize(context, v),
                      ),

                      const SizedBox(height: 24),
                      _SectionTitle(dark: dark, title: 'Preview'),
                      const SizedBox(height: 8),
                      _PreviewCard(
                        dark: dark,
                        arabicSize: controller.arabicFontSize,
                        translationSize: controller.translationFontSize,
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              QuranThemeScope.resetFontSizes(context),
                          icon: Icon(
                            Icons.restart_alt,
                            color: QuranTokens.brandColor(dark),
                          ),
                          label: Text(
                            'Reset',
                            style: QuranTokens.poppins(
                              QuranTokens.tsSurahName,
                            ).copyWith(color: QuranTokens.brandColor(dark)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: QuranTokens.brandColor(dark),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                QuranTokens.radiusButton,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ReminderSettingsSection(
                        reminder: QuranDependencies.reminder,
                        progress: QuranDependencies.murojaahProgress,
                      ),
                      const SizedBox(height: 24),
                      BackupSettingsSection(
                        progress: QuranDependencies.murojaahProgress,
                        reminder: QuranDependencies.reminder,
                      ),
                      const SizedBox(height: 24),
                    ],
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.dark, required this.title});

  final bool dark;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: QuranTokens.poppins(
        QuranTokens.tsSurahName,
      ).copyWith(color: QuranTokens.inkColor(dark)),
    );
  }
}

class _FontSizeSlider extends StatelessWidget {
  const _FontSizeSlider({
    required this.dark,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final bool dark;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final divisions = (max - min).toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: QuranTokens.surface(dark),
        borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: QuranTokens.brandColor(dark),
                    inactiveTrackColor: QuranTokens.secondaryColor(
                      dark,
                    ).withValues(alpha: 0.3),
                    thumbColor: QuranTokens.brandColor(dark),
                    overlayColor: QuranTokens.brandColor(
                      dark,
                    ).withValues(alpha: 0.1),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                  ),
                  child: Slider(
                    value: value.clamp(min, max),
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onChanged,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                alignment: Alignment.center,
                child: Text(
                  '${value.toInt()}',
                  style: QuranTokens.poppins(
                    QuranTokens.tsSurahName,
                  ).copyWith(color: QuranTokens.brandColor(dark)),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${min.toInt()}',
                style: QuranTokens.poppins(
                  QuranTokens.tsDetailMeta,
                ).copyWith(color: QuranTokens.secondaryColor(dark)),
              ),
              Text(
                '${max.toInt()}',
                style: QuranTokens.poppins(
                  QuranTokens.tsDetailMeta,
                ).copyWith(color: QuranTokens.secondaryColor(dark)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.dark,
    required this.arabicSize,
    required this.translationSize,
  });

  final bool dark;
  final double arabicSize;
  final double translationSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QuranTokens.surface(dark),
        borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: QuranTokens.amiri(QuranTokens.tsVerseArabic).copyWith(
              fontSize: arabicSize,
              color: QuranTokens.inkColor(dark),
              height: 1.9,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Dengan nama Allah Yang Maha Pengasih, Maha Penyayang.',
            style: QuranTokens.poppins(QuranTokens.tsVerseTranslation).copyWith(
              fontSize: translationSize,
              color: QuranTokens.secondaryColor(dark),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
