import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../../domain/entities/verse.dart';
import '../../../murojaah/progress/activity_entry.dart';
import '../../../murojaah/progress/progress_controller.dart';
import '../../../murojaah/progress/reading_dwell.dart';
import '../../../murojaah/progress/reading_log_recorder.dart';
import '../../../presentation/widgets/quran_theme_scope.dart';
import '../../application/tafsir_controller.dart';

/// Bottom sheet tafsir — menampilkan penjelasan ayat dari API equran.id.
///
/// Fitur:
/// - Teks Arab ayat di atas teks tafsir
/// - Navigasi prev/next ayat tanpa tutup sheet
/// - Loading shimmer + error state
/// - Drag handle untuk dismiss
class TafsirBottomSheet extends StatefulWidget {
  const TafsirBottomSheet({
    super.key,
    required this.controller,
    required this.verses,
    required this.surahNumber,
    required this.totalAyat,
    this.readingProgress,
  });

  final TafsirController controller;

  /// List ayat surah untuk tampilkan teks Arab per ayat aktif.
  final List<Verse> verses;
  final int surahNumber;
  final int totalAyat;

  /// Log aktivitas untuk mencatat "tafsir dibaca". Null = tidak mencatat.
  final MurojaahProgressController? readingProgress;

  static Future<void> show({
    required BuildContext context,
    required TafsirController controller,
    required List<Verse> verses,
    required int surahNumber,
    required int totalAyat,
    MurojaahProgressController? readingProgress,
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
        readingProgress: readingProgress,
      ),
    );
  }

  @override
  State<TafsirBottomSheet> createState() => _TafsirBottomSheetState();
}

class _TafsirBottomSheetState extends State<TafsirBottomSheet>
    with WidgetsBindingObserver {
  late final ReadingLogRecorder _recorder;
  int _activeAyat = 0;

  @override
  void initState() {
    super.initState();
    _recorder = ReadingLogRecorder(
      progress: widget.readingProgress,
      type: ActivityType.tafsir,
    );
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_syncActiveAyat);
    _syncActiveAyat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _recorder.handleLifecycle(state);
  }

  /// Satu ayat = satu item. Pindah ayat menutup item lama (kredit bila sudah
  /// lewat ambang) dan membuka item baru.
  void _syncActiveAyat() {
    final state = widget.controller.value;
    final ayat = state is TafsirLoaded && state.activeTafsir != null
        ? state.activeAyat
        : 0;
    if (ayat == _activeAyat) return;
    if (_activeAyat > 0) _recorder.leave('tafsir:$_activeAyat');
    _activeAyat = ayat;
    if (ayat > 0) {
      _recorder.enter(
        'tafsir:$ayat',
        surahNumber: widget.surahNumber,
        verse: ayat,
      );
    }
  }

  void _markRead() {
    _recorder.markVisibleAsRead();
    _recorder.flush();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncActiveAyat);
    WidgetsBinding.instance.removeObserver(this);
    _recorder
      ..flush()
      ..dispose();
    super.dispose();
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
                valueListenable: widget.controller,
                builder: (_, state, __) {
                  final ayat = state is TafsirLoaded ? state.activeAyat : 0;
                  return Row(
                    children: [
                      // Expanded, bukan Spacer: judul boleh membungkus saat teks
                      // diperbesar, bukan meluber keluar layar.
                      Expanded(
                        child: Text(
                          ayat > 0 ? 'Tafsir Ayat $ayat' : 'Tafsir',
                          style: QuranTokens.poppins(
                            const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ).copyWith(color: QuranTokens.inkColor(dark)),
                        ),
                      ),
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
                valueListenable: widget.controller,
                builder: (_, state, __) {
                  return switch (state) {
                    TafsirIdle() => const SizedBox.shrink(),
                    TafsirLoading() => _LoadingView(dark: dark),
                    TafsirError(:final message) =>
                      _ErrorView(message: message, dark: dark),
                    TafsirLoaded() => _ContentView(
                        state: state,
                        verses: widget.verses,
                        surahNumber: widget.surahNumber,
                        totalAyat: widget.totalAyat,
                        controller: widget.controller,
                        scrollController: scrollController,
                        dark: dark,
                        onMarkRead: _markRead,
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
    required this.onMarkRead,
  });

  final TafsirLoaded state;
  final List<Verse> verses;
  final int surahNumber;
  final int totalAyat;
  final TafsirController controller;
  final ScrollController scrollController;
  final bool dark;
  final VoidCallback onMarkRead;

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
                // Navigasi ikut menggulir: dengan teks diperbesar, bar navigasi
                // lebih tinggi dari sisa ruang dan akan menutupi teks tafsir
                // bila dipatok di bawah.
                _NavigationBar(
                  state: state,
                  totalAyat: totalAyat,
                  controller: controller,
                  dark: dark,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // Aksi utama tetap terlihat tanpa menggulir.
        Divider(height: 1, color: QuranTokens.listDivider(dark)),
        MarkReadButton(
          onPressed: onMarkRead,
          label: 'Tandai tafsir ini sudah dibaca',
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
              child: TextButton(
                onPressed: hasPrev ? controller.prevAyat : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_ios_new,
                      size: 14,
                      color: hasPrev ? brand : disabled,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Ayat Sebelumnya',
                        style: QuranTokens.poppins(
                          const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ).copyWith(color: hasPrev ? brand : disabled),
                      ),
                    ),
                  ],
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
              child: TextButton(
                onPressed: hasNext ? () => controller.nextAyat(totalAyat) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Ayat Berikutnya',
                        style: QuranTokens.poppins(
                          const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ).copyWith(color: hasNext ? brand : disabled),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: hasNext ? brand : disabled,
                    ),
                  ],
                ),
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
