import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../../murojaah/progress/activity_entry.dart';
import '../../../murojaah/progress/progress_controller.dart';
import '../../../murojaah/progress/reading_dwell.dart';
import '../../../murojaah/progress/reading_log_recorder.dart';
import '../../../presentation/widgets/quran_status_bar.dart';
import '../../../presentation/widgets/quran_theme_scope.dart';
import '../../application/doa_controller.dart';
import '../../domain/entities/doa.dart';
import '../widgets/doa_card.dart';

/// Halaman list doa dengan filter chips (grup + tag), search, dan bookmark.
class DoaListPage extends StatefulWidget {
  const DoaListPage({super.key, required this.controller, this.readingProgress});

  final DoaController controller;

  /// Log aktivitas untuk mencatat "doa dibaca". Null = tidak mencatat.
  final MurojaahProgressController? readingProgress;

  @override
  State<DoaListPage> createState() => _DoaListPageState();
}

class _DoaListPageState extends State<DoaListPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _searchVisible = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller.value is! DoaLoaded) {
      widget.controller.load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return QuranStatusBar(
      dark: dark,
      child: Scaffold(
        backgroundColor: QuranTokens.background(dark),
        body: SafeArea(
          child: ValueListenableBuilder<DoaState>(
            valueListenable: widget.controller,
            builder: (context, state, _) {
              return Column(
                children: [
                  _buildTopBar(context, dark, state),
                  if (_searchVisible) _buildSearchField(dark),
                  if (state is DoaLoaded)
                    _buildOfflineBanner(state, dark),
                  Expanded(child: _buildBody(context, state, dark)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, bool dark, DoaState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: QuranTokens.inkColor(dark),
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              'Doa & Dzikir',
              style: QuranTokens.poppins(
                QuranTokens.tsLastReadTitle,
              ).copyWith(
                color: QuranTokens.brandColor(dark),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (state is DoaLoaded)
            IconButton(
              onPressed: () {
                setState(() => _searchVisible = !_searchVisible);
                if (!_searchVisible) {
                  _searchController.clear();
                  widget.controller.search('');
                }
              },
              icon: Icon(
                _searchVisible ? Icons.search_off : Icons.search,
                color: QuranTokens.inkColor(dark),
              ),
            ),
        ],
      ),
    );
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Widget _buildSearchField(bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: widget.controller.search,
        style: QuranTokens.poppins(QuranTokens.tsSurahName)
            .copyWith(color: QuranTokens.inkColor(dark)),
        decoration: InputDecoration(
          hintText: 'Cari doa...',
          hintStyle: QuranTokens.poppins(QuranTokens.tsSurahMeta)
              .copyWith(color: QuranTokens.secondaryColor(dark)),
          prefixIcon:
              Icon(Icons.search, color: QuranTokens.secondaryColor(dark)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    widget.controller.search('');
                  },
                  icon: Icon(Icons.close,
                      color: QuranTokens.secondaryColor(dark)),
                )
              : null,
          filled: true,
          fillColor: QuranTokens.surface(dark),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── Offline banner ────────────────────────────────────────────────────────

  Widget _buildOfflineBanner(DoaLoaded state, bool dark) {
    if (!state.isOffline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colors.orange.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Menampilkan data tersimpan (offline)',
              style: QuranTokens.poppins(
                const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter tabs (Grup | Tag) ───────────────────────────────────────────────

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, DoaState state, bool dark) {
    if (state is DoaLoading) {
      return _buildShimmer(dark);
    }
    if (state is DoaError) {
      return _buildError(state.message, dark);
    }
    if (state is DoaLoaded) {
      return _buildList(context, state, dark);
    }
    return const SizedBox.shrink();
  }

  Widget _buildList(BuildContext context, DoaLoaded state, bool dark) {
    final doas = state.filtered;
    if (doas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48,
                color: QuranTokens.secondaryColor(dark)),
            const SizedBox(height: 12),
            Text(
              'Tidak ada doa ditemukan',
              style: QuranTokens.poppins(QuranTokens.tsSurahMeta)
                  .copyWith(color: QuranTokens.secondaryColor(dark)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: doas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final doa = doas[index];
        return DoaCard(
          key: ValueKey(doa.id),
          doa: doa,
          isBookmarked: state.isBookmarked(doa.id),
          dark: dark,
          onTap: () => _openDetail(context, doa),
          onBookmarkTap: () => widget.controller.toggleBookmark(doa.id),
        );
      },
    );
  }

  void _openDetail(BuildContext context, Doa doa) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoaDetailPage(
          doa: doa,
          isBookmarked: (widget.controller.value is DoaLoaded)
              ? (widget.controller.value as DoaLoaded).isBookmarked(doa.id)
              : false,
          onBookmarkTap: () => widget.controller.toggleBookmark(doa.id),
          controller: widget.controller,
          readingProgress: widget.readingProgress,
        ),
      ),
    );
  }

  Widget _buildError(String message, bool dark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48,
                color: QuranTokens.secondaryColor(dark)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: QuranTokens.poppins(QuranTokens.tsSurahMeta)
                  .copyWith(color: QuranTokens.secondaryColor(dark)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: widget.controller.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: QuranTokens.brandOf(context),
                foregroundColor: QuranTokens.onBrandOf(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer(bool dark) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 10,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, __) => _ShimmerCard(dark: dark),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: QuranTokens.surface(dark),
        borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: QuranTokens.shimmerBase(dark),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: QuranTokens.shimmerBase(dark),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 11,
                  width: 90,
                  decoration: BoxDecoration(
                    color: QuranTokens.shimmerBase(dark),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail page (defined here to keep navigation self-contained) ──────────────

class DoaDetailPage extends StatefulWidget {
  const DoaDetailPage({
    super.key,
    required this.doa,
    required this.isBookmarked,
    required this.onBookmarkTap,
    required this.controller,
    this.readingProgress,
  });

  final Doa doa;
  final bool isBookmarked;
  final VoidCallback onBookmarkTap;
  final DoaController controller;
  final MurojaahProgressController? readingProgress;

  @override
  State<DoaDetailPage> createState() => _DoaDetailPageState();
}

class _DoaDetailPageState extends State<DoaDetailPage>
    with WidgetsBindingObserver {
  bool _tentangExpanded = false;

  late final ReadingLogRecorder _recorder;

  @override
  void initState() {
    super.initState();
    _recorder = ReadingLogRecorder(
      progress: widget.readingProgress,
      type: ActivityType.doa,
    );
    WidgetsBinding.instance.addObserver(this);
    // Seluruh isi doa tampil sekaligus di halaman detail: satu item, satu timer.
    _recorder.enter(
      'doa:${widget.doa.id}',
      refId: '${widget.doa.id}',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _recorder.handleLifecycle(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recorder
      ..flush()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return QuranStatusBar(
      dark: dark,
      child: Scaffold(
        backgroundColor: QuranTokens.background(dark),
        body: SafeArea(
          child: ValueListenableBuilder<DoaState>(
            valueListenable: widget.controller,
            builder: (context, state, _) {
              final isBookmarked = state is DoaLoaded
                  ? state.isBookmarked(widget.doa.id)
                  : widget.isBookmarked;
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(context, dark, isBookmarked),
                  ),
                  SliverToBoxAdapter(
                    child: _buildContent(dark),
                  ),
                  SliverToBoxAdapter(
                    child: _buildMarkRead(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool dark, bool isBookmarked) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [QuranTokens.gradientStart, QuranTokens.gradientEnd],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onBookmarkTap,
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.doa.nama,
                  style: QuranTokens.poppins(
                    const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.doa.grup,
                  style: QuranTokens.poppins(
                    const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (widget.doa.tag.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: widget.doa.tag.map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          // Chip gelap, bukan putih transparan: putih di atas
                          // putih-20% hanya 3.4:1.
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          t,
                          style: QuranTokens.poppins(
                            const TextStyle(fontSize: 11, color: Colors.white),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tombol "Tandai sudah dibaca" — ikon + label, tinggi ≥48 px.
  Widget _buildMarkRead() {
    return MarkReadButton(
      onPressed: () {
        _recorder.markVisibleAsRead();
        _recorder.flush();
      },
    );
  }

  Widget _buildContent(bool dark) {
    final doa = widget.doa;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Arab
          if (doa.ar.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: QuranTokens.surface(dark),
                borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
              ),
              child: Text(
                doa.ar,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: QuranTokens.amiri(
                  TextStyle(
                    fontSize: 26,
                    height: 2.0,
                    color: QuranTokens.arabicNameColor(dark),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Transliterasi
          if (doa.tr.isNotEmpty) ...[
            _SectionLabel(label: 'Latin', dark: dark),
            const SizedBox(height: 6),
            Text(
              doa.tr,
              style: QuranTokens.poppins(
                TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  height: 1.7,
                  color: QuranTokens.inkColor(dark),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Terjemahan
          if (doa.idn.isNotEmpty) ...[
            _SectionLabel(label: 'Terjemahan', dark: dark),
            const SizedBox(height: 6),
            Text(
              doa.idn,
              style: QuranTokens.poppins(
                TextStyle(
                  fontSize: 15,
                  height: 1.7,
                  color: QuranTokens.inkColor(dark),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Keterangan & Dalil (collapsible)
          if (doa.tentang.isNotEmpty) ...[
            GestureDetector(
              onTap: () =>
                  setState(() => _tentangExpanded = !_tentangExpanded),
              child: Row(
                children: [
                  Expanded(
                    child: _SectionLabel(label: 'Keterangan & Dalil', dark: dark),
                  ),
                  Icon(
                    _tentangExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: QuranTokens.secondaryColor(dark),
                    size: 20,
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  doa.tentang,
                  style: QuranTokens.poppins(
                    TextStyle(
                      fontSize: 14,
                      height: 1.7,
                      color: QuranTokens.secondaryColor(dark),
                    ),
                  ),
                ),
              ),
              crossFadeState: _tentangExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.dark});
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: QuranTokens.poppins(
        TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: QuranTokens.brandColor(dark),
        ),
      ),
    );
  }
}
