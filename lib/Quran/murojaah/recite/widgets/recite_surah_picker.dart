import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../application/quran_controller.dart';
import '../../../application/quran_dependencies.dart';
import '../../../data/quran_tokens.dart';
import '../../../domain/entities/surah.dart';

/// Sheet pilih surah untuk latihan. Menggantikan halaman sekarang, bukan
/// menumpuk route, supaya tombol kembali tetap satu langkah.
Future<void> showReciteSurahPicker(
  BuildContext context, {
  required bool dark,
  required int current,
}) {
  final controller = QuranDependencies.controller;
  if (controller.surahs.isEmpty) unawaited(controller.load());
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: QuranTokens.surface(dark),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SurahPickerSheet(dark: dark, current: current),
  );
}

class _SurahPickerSheet extends StatelessWidget {
  const _SurahPickerSheet({required this.dark, required this.current});

  final bool dark;
  final int current;

  @override
  Widget build(BuildContext context) {
    final controller = QuranDependencies.controller;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: QuranTokens.border(dark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Text(
                'Pilih surah',
                style: QuranTokens.poppins(
                  TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: QuranTokens.inkColor(dark),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<QuranState>(
                valueListenable: controller,
                builder: (context, state, _) {
                  final surahs = controller.surahs;
                  if (surahs.isEmpty) {
                    return Center(
                      child: state.status == QuranLoadStatus.error
                          ? Text(
                              'Daftar surah gagal dimuat.',
                              style: QuranTokens.poppins(
                                TextStyle(
                                  fontSize: 14,
                                  color: QuranTokens.textMuted(dark),
                                ),
                              ),
                            )
                          : const CircularProgressIndicator(),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: surahs.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: QuranTokens.border(dark).withValues(alpha: 0.6),
                    ),
                    itemBuilder: (context, i) => _SurahTile(
                      surah: surahs[i],
                      dark: dark,
                      current: current,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({
    required this.surah,
    required this.dark,
    required this.current,
  });

  final Surah surah;
  final bool dark;
  final int current;

  @override
  Widget build(BuildContext context) {
    final active = surah.number == current;
    return ListTile(
      minVerticalPadding: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      tileColor: active ? QuranTokens.activeBg(dark) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: active
            ? QuranTokens.brandColor(dark)
            : QuranTokens.surfaceAlt(dark),
        child: Text(
          '${surah.number}',
          style: QuranTokens.poppins(
            TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: active
                  ? QuranTokens.onPrimaryColor(dark)
                  : QuranTokens.textMuted(dark),
            ),
          ),
        ),
      ),
      title: Text(
        surah.transliteration,
        style: QuranTokens.poppins(
          TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: QuranTokens.inkColor(dark),
          ),
        ),
      ),
      subtitle: Text(
        '${surah.translation} · ${surah.totalVerses} ayat',
        style: QuranTokens.poppins(
          TextStyle(fontSize: 14, color: QuranTokens.textMuted(dark)),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active)
            Icon(
              Icons.play_circle_fill_rounded,
              size: 20,
              color: QuranTokens.brandColor(dark),
            ),
          const SizedBox(width: 8),
          Text(
            surah.name,
            textDirection: TextDirection.rtl,
            style: QuranTokens.amiri(
              TextStyle(fontSize: 20, color: QuranTokens.brandColor(dark)),
            ),
          ),
        ],
      ),
      onTap: () {
        Navigator.of(context).maybePop();
        if (!active) {
          context.pushReplacement('/home/quran/murojaah/surah/${surah.number}');
        }
      },
    );
  }
}
