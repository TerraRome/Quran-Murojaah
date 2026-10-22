import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../../presentation/widgets/quran_theme_scope.dart';
import '../../progress/activity_entry.dart';
import '../../progress/progress_service.dart';

/// Ringkasan hari ini: empat jenis aktivitas dengan progres masing-masing.
///
/// Angka berasal dari [ProgressSnapshot.activities] — turunan log, bukan
/// penghitung terpisah. Status "selesai" ditandai ikon centang + teks, bukan
/// hanya warna.
class TodayActivitySummary extends StatelessWidget {
  const TodayActivitySummary({
    super.key,
    required this.snapshot,
    this.title = 'Hari ini',
  });

  final ProgressSnapshot snapshot;
  final String title;

  static const _order = [
    ActivityType.quranRead,
    ActivityType.murojaah,
    ActivityType.tafsir,
    ActivityType.doa,
  ];

  static const _icons = {
    ActivityType.quranRead: Icons.menu_book_rounded,
    ActivityType.murojaah: Icons.mic_none_rounded,
    ActivityType.tafsir: Icons.notes_rounded,
    ActivityType.doa: Icons.volunteer_activism_outlined,
  };

  static String _unitOf(ActivityType type) =>
      type == ActivityType.doa ? 'doa' : 'ayat';

  static int _targetOf(ActivityType type, DailyGoal goal) =>
      switch (type) {
        ActivityType.quranRead || ActivityType.murojaah => goal.verses,
        ActivityType.tafsir => 1,
        ActivityType.doa => 1,
      };


  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: QuranTokens.surface(dark),
          borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: QuranTokens.poppins(
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ).copyWith(color: QuranTokens.inkColor(dark)),
            ),
            const SizedBox(height: 12),
            for (final type in _order) ...[
              _ActivityRow(
                type: type,
                day: snapshot.activityOf(type),
                target: _targetOf(type, snapshot.goal),
                dark: dark,
              ),              if (type != _order.last) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.type,
    required this.day,
    required this.target,
    required this.dark,
  });

  final ActivityType type;
  final ActivityDay day;
  final int target;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final muted = QuranTokens.secondaryColor(dark);
    final ink = QuranTokens.inkColor(dark);
    final unit = TodayActivitySummary._unitOf(type);
    final status = day.done ? 'Selesai' : '${day.count} dari $target $unit';
    return Row(
      children: [
        Icon(
          TodayActivitySummary._icons[type],
          size: 20,
          color: day.done ? QuranTokens.correctOf(context) : muted,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            type.label,
            style: QuranTokens.poppins(
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ).copyWith(color: ink),
          ),
        ),
        const SizedBox(width: 8),
        if (day.done) ...[
          Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: QuranTokens.correctOf(context),
          ),
          const SizedBox(width: 4),
        ],
        // Flexible: status membungkus ke baris kedua saat teks diperbesar,
        // bukan meluber keluar kartu.
        Flexible(
          child: Text(
            status,
            textAlign: TextAlign.end,
            style: QuranTokens.poppins(const TextStyle(fontSize: 14))
                .copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}
