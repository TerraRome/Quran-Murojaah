import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../application/quran_controller.dart';
import '../../data/quran_tokens.dart';
import '../../doa/application/doa_controller.dart';
import '../../doa/presentation/pages/doa_list_page.dart';
import '../../domain/entities/surah.dart';
import '../../murojaah/presentation/pages/murojaah_page.dart';
import '../../murojaah/presentation/widgets/today_activity_summary.dart';
import '../../murojaah/progress/progress_controller.dart';
import '../../shalat/application/shalat_controller.dart';
import '../../shalat/presentation/pages/shalat_page.dart';
import '../widgets/quran_status_bar.dart';
import '../widgets/quran_theme_scope.dart';
import '../widgets/quran_top_bar.dart';
import '../widgets/surah_card.dart';

/// Home module Quran (Figma "Home"): greeting, kartu Last Read, daftar surah,
/// dan bottom tab (Quran - Murojaah - Shalat - Doa - Bookmark).
class QuranHomePage extends StatefulWidget {
  const QuranHomePage({
    super.key,
    required this.controller,
    required this.doaController,
    required this.shalatController,
    required this.murojaahProgress,
  });

  final QuranController controller;
  final DoaController doaController;
  final ShalatController shalatController;
  final MurojaahProgressController murojaahProgress;

  @override
  State<QuranHomePage> createState() => _QuranHomePageState();
}

class _QuranHomePageState extends State<QuranHomePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _searchVisible = false;
  String _query = '';
  int _tabIndex = 0;

  static const _bottomTabs = [
    _BottomTabItem(asset: 'assets/quran/quran.svg', label: 'Quran'),
    _BottomTabItem(asset: 'assets/quran/lamp.svg', label: 'Murojaah'),
    _BottomTabItem(asset: 'assets/quran/shalat.svg', label: 'Shalat'),
    _BottomTabItem(asset: 'assets/quran/doa.svg', label: 'Doa'),
    _BottomTabItem(asset: 'assets/quran/bookmark.svg', label: 'Bookmark'),
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.load();
    widget.controller.loadLastRead();
    // Jumlah ayat per surah disuntikkan ke mesin progres: bonus "satu surah
    // tamat" diturunkan dari log + angka ini, tanpa field baru di entri.
    widget.murojaahProgress.verseCount = (number) =>
        widget.controller.surahs
            .where((s) => s.number == number)
            .firstOrNull
            ?.totalVerses ??
        0;
    if (!widget.murojaahProgress.isLoaded) {
      widget.murojaahProgress.load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Surah> get _filteredSurahs {
    final surahs = widget.controller.surahs;
    if (_query.isEmpty) {
      return surahs;
    }
    return surahs
        .where(
          (surah) =>
              surah.transliteration.toLowerCase().contains(
                _query.toLowerCase(),
              ) ||
              surah.translation.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return QuranStatusBar(
      dark: dark,
      child: Scaffold(
        backgroundColor: QuranTokens.background(dark),
        body: SafeArea(
          child: ValueListenableBuilder<QuranState>(
            valueListenable: widget.controller,
            builder: (context, state, _) {
              return Column(
                children: [
                  const SizedBox(height: 12),
                  QuranTopBar(
                    title: _tabIndex == 0
                        ? 'Quran App'
                        : _bottomTabs[_tabIndex].label,
                    titleColor: QuranTokens.brandColor(dark),
                    leading: IconButton(
                      onPressed: () => _showMenu(context, dark),
                      padding: EdgeInsets.zero,
                      icon: const QuranHeaderIcon(
                        asset: 'assets/quran/menu_line.svg',
                      ),
                    ),
                    onSearch: _tabIndex == 0
                        ? () => setState(() {
                              _searchVisible = !_searchVisible;
                            })
                        : null,
                  ),
                  if (_searchVisible && _tabIndex == 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: _SearchField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        onClear: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        dark: dark,
                      ),
                    ),
                  Expanded(
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (_tabIndex == 0) ...[
                          SliverToBoxAdapter(child: _Greeting(dark: dark)),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          if (_query.isEmpty)
                            SliverToBoxAdapter(
                              child: _LastReadCard(
                                controller: widget.controller,
                                dark: dark,
                              ),
                            ),
                          if (_query.isEmpty)
                            SliverToBoxAdapter(
                              child: ListenableBuilder(
                                listenable: widget.murojaahProgress,
                                builder: (context, _) => TodayActivitySummary(
                                  snapshot: widget.murojaahProgress.snapshot(),
                                ),
                              ),
                            ),
                        ],
                        ..._buildContentSlivers(state, dark),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        bottomNavigationBar: _QuranBottomNav(
          tabs: _bottomTabs,
          selectedIndex: _tabIndex,
          dark: dark,
          onChanged: (index) => setState(() => _tabIndex = index),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, bool dark) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: QuranTokens.surface(dark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: QuranTokens.secondaryColor(
                    dark,
                  ).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                secondary: Icon(
                  dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: QuranTokens.arabicNameColor(dark),
                ),
                title: Text(
                  'Mode Gelap',
                  style: QuranTokens.poppins(
                    QuranTokens.tsSurahName,
                  ).copyWith(color: QuranTokens.inkColor(dark)),
                ),
                value: dark,
                onChanged: (_) => QuranThemeScope.toggleDark(context),
              ),
              Divider(height: 1, color: QuranTokens.divider(dark)),
              ListTile(
                leading: Icon(
                  Icons.text_fields,
                  color: QuranTokens.arabicNameColor(dark),
                ),
                title: Text(
                  'Pengaturan',
                  style: QuranTokens.poppins(
                    QuranTokens.tsSurahName,
                  ).copyWith(color: QuranTokens.inkColor(dark)),
                ),
                subtitle: Text(
                  'Ukuran font Arab & terjemahan',
                  style: QuranTokens.poppins(
                    QuranTokens.tsSurahMeta,
                  ).copyWith(color: QuranTokens.secondaryColor(dark)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/home/quran/settings');
                },
              ),
              Divider(height: 1, color: QuranTokens.divider(dark)),
              ListTile(
                leading: Icon(
                  Icons.headphones_rounded,
                  color: QuranTokens.arabicNameColor(dark),
                ),
                title: Text(
                  'Murottal',
                  style: QuranTokens.poppins(
                    QuranTokens.tsSurahName,
                  ).copyWith(color: QuranTokens.inkColor(dark)),
                ),
                subtitle: Text(
                  'Qari & file audio tersimpan',
                  style: QuranTokens.poppins(
                    QuranTokens.tsSurahMeta,
                  ).copyWith(color: QuranTokens.secondaryColor(dark)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/home/quran/murottal-settings');
                },
              ),
              Divider(height: 1, color: QuranTokens.divider(dark)),
              ListTile(
                leading: Icon(
                  Icons.menu_book_outlined,
                  color: QuranTokens.arabicNameColor(dark),
                ),
                title: Text(
                  'Tentang Quran App',
                  style: QuranTokens.poppins(
                    QuranTokens.tsSurahName,
                  ).copyWith(color: QuranTokens.inkColor(dark)),
                ),
                subtitle: Text(
                  '114 surah · 6236 ayat · offline',
                  style: QuranTokens.poppins(
                    QuranTokens.tsSurahMeta,
                  ).copyWith(color: QuranTokens.secondaryColor(dark)),
                ),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildContentSlivers(QuranState state, bool dark) {
    if (_tabIndex == 1) {
      return [
        MurojaahPage(
          controller: widget.controller,
          progress: widget.murojaahProgress,
        ),
      ];
    }
    if (_tabIndex == 2) {
      return [
        SliverFillRemaining(
          hasScrollBody: true,
          child: ShalatPage(controller: widget.shalatController),
        ),
      ];
    }
    if (_tabIndex == 3) {
      return [
        SliverFillRemaining(
          hasScrollBody: true,
          child: DoaListPage(
            controller: widget.doaController,
            readingProgress: widget.murojaahProgress,
          ),
        ),
      ];
    }
    if (_tabIndex != 0) {
      final tab = _bottomTabs[_tabIndex];
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(
            icon: SvgPicture.asset(
              tab.asset,
              width: 48,
              height: 48,
              colorFilter: ColorFilter.mode(
                QuranTokens.secondaryColor(dark),
                BlendMode.srcIn,
              ),
            ),
            message: '${tab.label} — Segera hadir',
            dark: dark,
          ),
        ),
      ];
    }
    if (state.isLoading) {
      return [SliverToBoxAdapter(child: _SurahListShimmer(dark: dark))];
    }
    if (state.isError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(
            icon: Icon(
              Icons.error_outline,
              size: 48,
              color: QuranTokens.secondaryColor(dark),
            ),
            message: 'Gagal memuat Al-Quran',
            dark: dark,
          ),
        ),
      ];
    }
    final surahs = _filteredSurahs;
    if (surahs.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(
            icon: Icon(
              Icons.search_off,
              size: 48,
              color: QuranTokens.secondaryColor(dark),
            ),
            message: 'Tidak ada surah ditemukan',
            dark: dark,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        sliver: SliverList.separated(
          itemCount: surahs.length,
          separatorBuilder: (_, _) =>
              Container(height: 1, color: QuranTokens.listDivider(dark)),
          itemBuilder: (context, index) {
            final surah = surahs[index];
            return SurahCard(
              key: ValueKey(surah.number),
              surah: surah,
              onTap: () => context.push('/home/quran/surah/${surah.number}'),
            );
          },
        ),
      ),
    ];
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Asslamualaikum',
            style: QuranTokens.poppins(
              QuranTokens.tsGreeting,
            ).copyWith(color: QuranTokens.secondaryColor(dark)),
          ),
          const SizedBox(height: 4),
          Text(
            'Ayo baca Al-Quran hari ini',
            style: QuranTokens.poppins(
              QuranTokens.tsUserName,
            ).copyWith(color: QuranTokens.inkColor(dark)),
          ),
        ],
      ),
    );
  }
}

/// Kartu "Last Read" (Figma "Last Read"): gradient, tag + nama surah + ayat.
class _LastReadCard extends StatelessWidget {
  const _LastReadCard({required this.controller, required this.dark});

  final QuranController controller;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final lastRead = controller.lastRead;
    final surah = controller.surahs
        .where((item) => item.number == lastRead?.surahNumber)
        .firstOrNull;
    final surahName = surah?.transliteration ?? 'Al-Fatihah';
    final verseLabel = 'Ayah No: ${lastRead?.verseNumber ?? 1}';
    final target = lastRead?.surahNumber ?? 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: InkWell(
        onTap: () => context.push('/home/quran/surah/$target'),
        borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [QuranTokens.gradientStart, QuranTokens.gradientEnd],
            ),
            borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                bottom: 0,
                child: Image.asset('assets/quran/mushaf.png', width: 160),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 19, 20, 19),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Last Read',
                          style: QuranTokens.poppins(
                            QuranTokens.tsLastReadTag,
                          ).copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 21),
                    Text(
                      surahName,
                      style: QuranTokens.poppins(
                        QuranTokens.tsLastReadTitle,
                      ).copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      verseLabel,
                      style: QuranTokens.poppins(
                        QuranTokens.tsLastReadSub,
                      ).copyWith(color: Colors.white),
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

/// Skeleton shimmer untuk list surah saat loading.
class _SurahListShimmer extends StatelessWidget {
  const _SurahListShimmer({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: QuranTokens.shimmerBase(dark),
      highlightColor: QuranTokens.shimmerHighlight(dark),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          children: [
            for (var i = 0; i < 8; i++) ...[
              if (i > 0)
                Container(height: 1, color: QuranTokens.listDivider(dark)),
              _ShimmerRow(dark: dark),
            ],
          ],
        ),
      ),
    );
  }
}

/// Satu baris skeleton shimmer (lingkaran + dua blok teks + blok meta).
class _ShimmerRow extends StatelessWidget {
  const _ShimmerRow({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: QuranTokens.surface(dark),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 12,
                  decoration: BoxDecoration(
                    color: QuranTokens.surface(dark),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 180,
                  height: 14,
                  decoration: BoxDecoration(
                    color: QuranTokens.surface(dark),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 24,
            decoration: BoxDecoration(
              color: QuranTokens.surface(dark),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state seragam (loading error, tab belum ada, pencarian kosong).
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.dark,
  });

  final Widget icon;
  final String message;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: QuranTokens.poppins(
              QuranTokens.tsSurahName,
            ).copyWith(color: QuranTokens.secondaryColor(dark)),
          ),
        ],
      ),
    );
  }
}

/// Definisi satu item bottom tab.
class _BottomTabItem {
  const _BottomTabItem({required this.asset, required this.label});

  final String asset;
  final String label;
}

/// Bottom navigation icon-only: aktif = brand, nonaktif = abu-abu.
class _QuranBottomNav extends StatelessWidget {
  const _QuranBottomNav({
    required this.tabs,
    required this.selectedIndex,
    required this.dark,
    required this.onChanged,
  });

  final List<_BottomTabItem> tabs;
  final int selectedIndex;
  final bool dark;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: QuranTokens.background(dark),
        border: Border(
          top: BorderSide(color: QuranTokens.divider(dark)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    borderRadius: BorderRadius.circular(8),
                    child: Center(
                      child: QuranHeaderIcon(
                        asset: tabs[i].asset,
                        color: i == selectedIndex
                            ? QuranTokens.brandColor(dark)
                            : QuranTokens.secondaryColor(dark),
                      ),
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.dark,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: true,
      style: QuranTokens.poppins(
        QuranTokens.tsSurahName,
      ).copyWith(color: QuranTokens.inkColor(dark)),
      decoration: InputDecoration(
        hintText: 'Cari surah...',
        hintStyle: QuranTokens.poppins(
          QuranTokens.tsSurahName,
        ).copyWith(color: QuranTokens.secondaryColor(dark)),
        prefixIcon: Icon(Icons.search, color: QuranTokens.secondaryColor(dark)),
        suffixIcon: IconButton(
          onPressed: onClear,
          icon: const Icon(Icons.close),
          color: QuranTokens.secondaryColor(dark),
        ),
        filled: true,
        fillColor: QuranTokens.surface(dark),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
