import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../progress/progress_service.dart';

/// Baris tujuh hari terakhir di tab Murojaah.
///
/// Murni presentasional: hari, status, dan penanda "hari ini" datang dari
/// `ProgressService.weeklyDays`, bukan dihitung ulang di sini.
///
/// Status tidak pernah hanya warna — tiap keadaan punya bentuk dan ikon sendiri:
/// - aktif: lingkaran terisi + ikon centang,
/// - libur gratis: kotak membulat + ikon jeda,
/// - kosong: lingkaran bergaris tepi + garis pendek.
class MurojaahWeekCalendar extends StatelessWidget {
  const MurojaahWeekCalendar({super.key, required this.days});

  final List<DayActivity> days;

  static const shortNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const longNames = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Row + Expanded: tujuh kolom selalu muat, termasuk di lebar 360px.
    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: _DayColumn(day: day, dark: dark),
          ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day, required this.dark});

  final DayActivity day;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final index = (day.day.weekday - 1).clamp(0, 6);
    final status = day.active
        ? 'sudah membaca'
        : day.freeRest
        ? 'hari libur'
        : 'belum membaca';
    final label =
        '${MurojaahWeekCalendar.longNames[index]}, $status'
        '${day.isToday ? ', hari ini' : ''}';

    return Semantics(
      label: label,
      container: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                MurojaahWeekCalendar.shortNames[index],
                maxLines: 1,
                style: QuranTokens.poppins(QuranTokens.tsLastReadSub).copyWith(
                  color: day.isToday
                      ? QuranTokens.inkColor(dark)
                      : QuranTokens.textMuted(dark),
                  fontWeight: day.isToday ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 6),
              _Marker(day: day, dark: dark),
              const SizedBox(height: 6),
              Text(
                '${day.day.day}',
                maxLines: 1,
                style: QuranTokens.poppins(QuranTokens.tsLastReadSub).copyWith(
                  color: day.active || day.isToday
                      ? QuranTokens.inkColor(dark)
                      : QuranTokens.textMuted(dark),
                  fontWeight: day.isToday ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Penanda bentuk per status: bentuk berbeda + ikon berbeda, bukan warna saja.
class _Marker extends StatelessWidget {
  const _Marker({required this.day, required this.dark});

  final DayActivity day;
  final bool dark;

  static const _size = 30.0;

  @override
  Widget build(BuildContext context) {
    final todayRing = Border.all(
      color: day.isToday ? QuranTokens.inkColor(dark) : Colors.transparent,
      width: 2,
    );

    if (day.active) {
      return Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: QuranTokens.activeBg(dark),
          shape: BoxShape.circle,
          border: todayRing,
        ),
        child: Icon(
          Icons.check_rounded,
          size: 18,
          color: QuranTokens.correct(dark),
        ),
      );
    }

    if (day.freeRest) {
      return Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: day.isToday
                ? QuranTokens.inkColor(dark)
                : QuranTokens.textMuted(dark),
            width: 2,
          ),
        ),
        child: Icon(
          Icons.pause_rounded,
          size: 18,
          color: QuranTokens.textMuted(dark),
        ),
      );
    }

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: day.isToday
            ? todayRing
            : Border.all(color: QuranTokens.border(dark)),
      ),
      child: Center(
        child: Container(width: 10, height: 2, color: QuranTokens.border(dark)),
      ),
    );
  }
}
