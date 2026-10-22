import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/quran_tokens.dart';

const _seenKey = 'recite_onboarding_seen';

/// Apakah panduan singkat sudah pernah ditutup user.
Future<bool> reciteOnboardingSeen() async =>
    (await SharedPreferences.getInstance()).getBool(_seenKey) ?? false;

Future<void> markReciteOnboardingSeen() async =>
    (await SharedPreferences.getInstance()).setBool(_seenKey, true);

/// Panduan 3 langkah. Muncul sendiri sekali di awal, bisa dibuka lagi dari
/// tombol bantuan `?` di header.
Future<void> showReciteOnboarding(
  BuildContext context, {
  required bool dark,
  VoidCallback? onChangeSurah,
}) {
  unawaited(markReciteOnboardingSeen());
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: QuranTokens.surface(dark),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) =>
        ReciteOnboardingSheet(dark: dark, onChangeSurah: onChangeSurah),
  );
}

class ReciteOnboardingSheet extends StatelessWidget {
  const ReciteOnboardingSheet({
    super.key,
    required this.dark,
    this.onChangeSurah,
  });

  final bool dark;
  final VoidCallback? onChangeSurah;

  @override
  Widget build(BuildContext context) {
    final brand = QuranTokens.brandColor(dark);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: 16),
            Text(
              'Cara memakai latihan ini',
              textAlign: TextAlign.center,
              style: QuranTokens.poppins(
                TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: QuranTokens.inkColor(dark),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tiga langkah, tanpa perlu mengatur apa pun.',
              textAlign: TextAlign.center,
              style: QuranTokens.poppins(
                TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: QuranTokens.textMuted(dark),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _Step(
              dark: dark,
              icon: Icons.mic,
              title: 'Tekan mikrofon, lalu baca',
              body: 'Baca dengan suara biasa. Tidak perlu terburu-buru.',
            ),
            const SizedBox(height: 14),
            _Step(
              dark: dark,
              icon: Icons.visibility_outlined,
              title: 'Kotak putus-putus belum terbuka',
              body:
                  'Baca terus sampai katanya berwarna hijau dan bergaris centang. Itu tanda bacaanmu sudah pas.',
            ),
            const SizedBox(height: 14),
            _Step(
              dark: dark,
              icon: Icons.help_outline,
              title: 'Kata bergaris merah perlu diulang',
              body:
                  'Ketuk kata bergaris merah untuk melihat kata yang seharusnya, lalu ulangi ayatnya.',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: brand,
                foregroundColor: QuranTokens.onPrimaryColor(dark),
                textStyle: QuranTokens.poppins(
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Mengerti'),
            ),
            if (onChangeSurah != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: onChangeSurah,
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('Pilih surah lain'),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: QuranTokens.textMuted(dark),
                  textStyle: QuranTokens.poppins(
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Panduan ini bisa dibuka lagi lewat tombol ?',
              textAlign: TextAlign.center,
              style: QuranTokens.poppins(
                TextStyle(fontSize: 14, color: QuranTokens.textMuted(dark)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.dark,
    required this.icon,
    required this.title,
    required this.body,
  });

  final bool dark;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final brand = QuranTokens.brandColor(dark);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: brand.withValues(alpha: dark ? 0.22 : 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: QuranTokens.poppins(
                  TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: QuranTokens.inkColor(dark),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: QuranTokens.poppins(
                  TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: QuranTokens.textMuted(dark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
