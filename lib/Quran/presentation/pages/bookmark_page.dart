import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../application/bookmark.dart';
import '../../application/bookmark_controller.dart';
import '../../application/quran_controller.dart';
import '../../data/quran_tokens.dart';
import '../widgets/quran_theme_scope.dart';
import '../widgets/quran_top_bar.dart';

/// Isi tab Bookmark (BC-06): ayat tersimpan, terbaru di atas. Ketuk baris
/// membuka surah dan scroll ke ayat itu.
class BookmarkPage extends StatelessWidget {
  const BookmarkPage({
    super.key,
    required this.bookmarks,
    required this.controller,
  });

  final BookmarkController bookmarks;
  final QuranController controller;

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return ListenableBuilder(
      listenable: bookmarks,
      builder: (context, _) {
        final items = bookmarks.items;
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QuranHeaderIcon(
                    asset: 'assets/quran/bookmark.svg',
                    color: QuranTokens.secondaryColor(dark),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada ayat yang disimpan. Ketuk ikon simpan di '
                    'samping ayat untuk menyimpannya.',
                    textAlign: TextAlign.center,
                    style: QuranTokens.poppins(
                      QuranTokens.tsSurahName,
                    ).copyWith(color: QuranTokens.secondaryColor(dark)),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, _) =>
              Container(height: 1, color: QuranTokens.listDivider(dark)),
          itemBuilder: (context, index) => _BookmarkRow(
            bookmark: items[index],
            controller: controller,
            bookmarks: bookmarks,
            dark: dark,
          ),
        );
      },
    );
  }
}

class _BookmarkRow extends StatelessWidget {
  const _BookmarkRow({
    required this.bookmark,
    required this.controller,
    required this.bookmarks,
    required this.dark,
  });

  final Bookmark bookmark;
  final QuranController controller;
  final BookmarkController bookmarks;
  final bool dark;

  void _remove(BuildContext context) {
    bookmarks.remove(bookmark.surah, bookmark.ayat);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Ayat dihapus'),
          // Snackbar bertombol aksi defaultnya tidak hilang sendiri.
          persist: false,
          // merge() mempertahankan savedAt asli, jadi posisi urutan kembali.
          action: SnackBarAction(
            label: 'Batal',
            onPressed: () => bookmarks.merge([bookmark]),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final surah = controller.surahs
        .where((s) => s.number == bookmark.surah)
        .firstOrNull;
    final name = surah?.transliteration ?? 'Surah ${bookmark.surah}';
    final translation = surah?.verses
        .where((v) => v.numberInSurah == bookmark.ayat)
        .firstOrNull
        ?.translation;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => context.push(
              '/home/quran/surah/${bookmark.surah}?ayat=${bookmark.ayat}',
            ),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name · Ayat ${bookmark.ayat}',
                      style: QuranTokens.poppins(
                        QuranTokens.tsSurahName,
                      ).copyWith(color: QuranTokens.inkColor(dark)),
                    ),
                    if (translation != null && translation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        translation,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: QuranTokens.poppins(
                          QuranTokens.tsSurahMeta,
                        ).copyWith(color: QuranTokens.secondaryColor(dark)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Hapus simpanan ayat ${bookmark.ayat} $name',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () => _remove(context),
          icon: const Icon(Icons.delete_outline_rounded, size: 24),
          color: QuranTokens.secondaryColor(dark),
        ),
      ],
    );
  }
}
