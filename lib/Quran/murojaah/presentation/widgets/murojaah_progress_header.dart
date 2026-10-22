import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../progress/progress_controller.dart';
import '../../progress/progress_service.dart';
import 'murojaah_goal_picker.dart';
import 'murojaah_week_calendar.dart';

/// Ringkasan progres hari ini di tab Murojaah: cincin target ayat, streak, dan
/// XP/level.
///
/// Tenang, bukan bergaya game: tanpa maskot, tanpa badge, tanpa animasi. Setiap
/// status selalu punya ikon atau bentuk di samping warna, jadi tetap terbaca
/// tanpa membedakan warna.
///
/// Widget ini hidup: ia mendengarkan [MurojaahProgressController], jadi angka
/// ikut berubah begitu sesi murojaah mencatat bacaan. Pemanggilan `load()`
/// tanggung jawab halaman induk.
class MurojaahProgressHeader extends StatelessWidget {
  const MurojaahProgressHeader({super.key, required this.progress});

  final MurojaahProgressController progress;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        // Satu "sekarang" per build: cincin, streak, dan kalender tidak boleh
        // melihat hari yang berbeda saat build tepat melewati tengah malam.
        final now = DateTime.now();
        final card = _card(
          dark: dark,
          child: progress.isLoaded
              ? _content(context, dark, progress.snapshot(now: now), now)
              : _Placeholder(dark: dark),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
          child: card,
        );
      },
    );
  }

  Widget _card({required bool dark, required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: QuranTokens.surfaceAlt(dark),
      border: Border.all(color: QuranTokens.border(dark)),
      borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
      boxShadow: QuranTokens.cardShadow(dark),
    ),
    child: child,
  );

  Widget _content(
    BuildContext context,
    bool dark,
    ProgressSnapshot snap,
    DateTime now,
  ) {
    final ink = QuranTokens.inkColor(dark);
    final muted = QuranTokens.textMuted(dark);
    // Log kosong: ajakan mulai, bukan deretan nol.
    final empty = progress.entries.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GoalRing(
              fraction: empty ? 0 : snap.goalFraction,
              reached: !empty && snap.goalReached,
              verses: snap.todayVerses,
              goal: snap.goal.verses,
              empty: empty,
              dark: dark,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    empty ? 'Belum ada bacaan' : 'Target hari ini',
                    style: QuranTokens.poppins(
                      QuranTokens.tsLastReadSub,
                    ).copyWith(color: muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    empty
                        ? 'Mulai dari satu ayat'
                        : '${snap.todayVerses} dari ${snap.goal.verses} ayat',
                    style: QuranTokens.poppins(
                      QuranTokens.tsSurahName,
                    ).copyWith(color: ink, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  _statusLine(dark, snap, empty: empty),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _goalButton(context, dark, snap.goal),
        const SizedBox(height: 8),
        Container(height: 1, color: QuranTokens.border(dark)),
        const SizedBox(height: 12),
        MurojaahWeekCalendar(
          days: ProgressService(progress.entries).weeklyDays(now: now),
        ),
        if (!empty) ...[
          const SizedBox(height: 12),
          Container(height: 1, color: QuranTokens.border(dark)),
          const SizedBox(height: 12),
          _streakLine(dark, snap.streak),
          const SizedBox(height: 6),
          _levelLine(dark, snap),
        ],
      ],
    );
  }

  /// Tombol "Atur target": berikon + berlabel, tinggi ≥48px, selalu terlihat
  /// termasuk saat log kosong.
  Widget _goalButton(BuildContext context, bool dark, DailyGoal goal) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () async {
          final picked = await showMurojaahGoalPicker(context, current: goal);
          if (picked != null) await progress.setGoal(picked);
        },
        icon: const Icon(Icons.tune_rounded, size: 20),
        label: const Text('Atur target'),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: QuranTokens.inkColor(dark),
          textStyle: QuranTokens.poppins(QuranTokens.tsLastReadSub),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
            side: BorderSide(color: QuranTokens.border(dark)),
          ),
        ),
      ),
    );
  }

  /// Baris status target: selalu ikon + teks, tidak pernah warna saja.
  Widget _statusLine(bool dark, ProgressSnapshot snap, {required bool empty}) {
    final muted = QuranTokens.textMuted(dark);
    if (empty) {
      return _line(
        icon: Icons.play_arrow_rounded,
        iconColor: muted,
        text: 'Pilih surat di bawah untuk mulai.',
        color: muted,
      );
    }
    if (snap.goalReached) {
      return _line(
        icon: Icons.check_circle_rounded,
        iconColor: QuranTokens.correct(dark),
        text: 'Target hari ini tercapai',
        color: QuranTokens.inkColor(dark),
        weight: FontWeight.w600,
      );
    }
    return _line(
      icon: Icons.trending_up_rounded,
      iconColor: muted,
      text: 'Sisa ${snap.remaining} ayat lagi',
      color: muted,
    );
  }

  Widget _streakLine(bool dark, int streak) {
    if (streak <= 0) {
      return _line(
        icon: Icons.local_fire_department_outlined,
        iconColor: QuranTokens.textMuted(dark),
        text: 'Baca hari ini untuk mulai streak',
        color: QuranTokens.textMuted(dark),
      );
    }
    return _line(
      icon: Icons.local_fire_department_rounded,
      iconColor: QuranTokens.streak(dark),
      text: '$streak hari berturut-turut',
      color: QuranTokens.inkColor(dark),
    );
  }

  Widget _levelLine(bool dark, ProgressSnapshot snap) {
    final total = snap.totalXp;
    return Row(
      children: [
        Icon(Icons.auto_awesome_rounded, size: 18, color: QuranTokens.xp(dark)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Level ${snap.level} · ${snap.xpIntoLevel}/'
            '${ProgressSnapshot.xpPerLevel} XP',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: QuranTokens.poppins(
              QuranTokens.tsLastReadSub,
            ).copyWith(color: QuranTokens.inkColor(dark)),
          ),
        ),
        if (total > 0) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Total $total XP',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: QuranTokens.poppins(
                QuranTokens.tsLastReadSub,
              ).copyWith(color: QuranTokens.textMuted(dark)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _line({
    required IconData icon,
    required Color iconColor,
    required String text,
    required Color color,
    FontWeight? weight,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: iconColor),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: QuranTokens.poppins(
            QuranTokens.tsLastReadSub,
          ).copyWith(color: color, fontWeight: weight),
        ),
      ),
    ],
  );
}

/// Cincin tipis target harian. Terisi sebagian = belum selesai; penuh + ikon
/// centang = selesai. Angka di tengah selalu menunjukkan `selesai/target`.
class _GoalRing extends StatelessWidget {
  const _GoalRing({
    required this.fraction,
    required this.reached,
    required this.verses,
    required this.goal,
    required this.empty,
    required this.dark,
  });

  final double fraction;
  final bool reached;
  final int verses;
  final int goal;
  final bool empty;
  final bool dark;

  static const _size = 64.0;

  @override
  Widget build(BuildContext context) {
    final label = '$verses/$goal';
    return Semantics(
      label: empty
          ? 'Target harian belum dimulai'
          : 'Target harian $verses dari $goal ayat',
      child: SizedBox(
        width: _size,
        height: _size,
        child: CustomPaint(
          painter: _RingPainter(
            fraction: fraction,
            track: QuranTokens.border(dark),
            arc: QuranTokens.correct(dark),
          ),
          child: Center(
            child: empty
                ? Icon(
                    Icons.menu_book_outlined,
                    size: 22,
                    color: QuranTokens.textMuted(dark),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (reached)
                        Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: QuranTokens.correct(dark),
                        ),
                      Text(
                        label,
                        style: QuranTokens.poppins(QuranTokens.tsLastReadSub)
                            .copyWith(
                              color: QuranTokens.inkColor(dark),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.track,
    required this.arc,
  });

  final double fraction;
  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (fraction <= 0) return;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = arc;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.track != track || old.arc != arc;
}

/// Placeholder saat log belum dimuat. Tingginya disamakan dengan isi asli
/// supaya daftar surah tidak melompat saat data datang.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width) => Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: QuranTokens.border(dark),
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: _GoalRing._size,
              height: _GoalRing._size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: QuranTokens.border(dark), width: 5),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(96),
                const SizedBox(height: 8),
                bar(140),
                const SizedBox(height: 8),
                bar(120),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(height: 1, color: QuranTokens.border(dark)),
        const SizedBox(height: 12),
        bar(160),
        const SizedBox(height: 8),
        bar(180),
      ],
    );
  }
}
