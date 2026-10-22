import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../progress/progress_service.dart';

/// Bottom sheet pemilih target harian.
///
/// Mengembalikan target yang dipilih, atau null bila sheet ditutup tanpa
/// memilih. Tidak memuat ulang apa pun: penyimpanan adalah tugas pemanggil
/// (`MurojaahProgressController.setGoal`).
Future<DailyGoal?> showMurojaahGoalPicker(
  BuildContext context, {
  required DailyGoal current,
}) {
  return showModalBottomSheet<DailyGoal>(
    context: context,
    backgroundColor: QuranTokens.surface(
      Theme.of(context).brightness == Brightness.dark,
    ),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _GoalPickerSheet(current: current),
  );
}

class _GoalPickerSheet extends StatelessWidget {
  const _GoalPickerSheet({required this.current});

  final DailyGoal current;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
              'Atur target harian',
              style: QuranTokens.poppins(QuranTokens.tsSurahName).copyWith(
                color: QuranTokens.inkColor(dark),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih berapa ayat yang ingin kamu baca tiap hari.',
              style: QuranTokens.poppins(
                QuranTokens.tsLastReadSub,
              ).copyWith(color: QuranTokens.textMuted(dark)),
            ),
            const SizedBox(height: 12),
            for (final goal in DailyGoal.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _GoalRow(
                  goal: goal,
                  selected: goal == current,
                  dark: dark,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.goal,
    required this.selected,
    required this.dark,
  });

  final DailyGoal goal;
  final bool selected;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${goal.label}, ${goal.detail}',
      child: Material(
        color: selected ? QuranTokens.activeBg(dark) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => Navigator.of(context).pop(goal),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            // Target sentuh jauh di atas 48px.
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              // Pilihan aktif: garis tepi, bukan warna saja.
              border: Border.all(
                color: selected
                    ? QuranTokens.correct(dark)
                    : QuranTokens.border(dark),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.label,
                        style: QuranTokens.poppins(QuranTokens.tsSurahName)
                            .copyWith(
                              color: QuranTokens.inkColor(dark),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        goal.detail,
                        style: QuranTokens.poppins(
                          QuranTokens.tsLastReadSub,
                        ).copyWith(color: QuranTokens.textMuted(dark)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${goal.verses} ayat',
                  style: QuranTokens.poppins(QuranTokens.tsSurahName).copyWith(
                    color: QuranTokens.inkColor(dark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                // Ikon centang = penanda pilihan, bukan hanya warna.
                SizedBox(
                  width: 24,
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 22,
                          color: QuranTokens.correct(dark),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
