import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../progress/record_result.dart';

/// Layar penutup satu sesi murojaah: perayaan kecil, ringkasan angka, dan
/// pilihan langkah berikutnya.
///
/// Nada tenang: satu perayaan, tanpa maskot, tanpa suara. Semua status punya
/// ikon di samping warna. Saat sistem meminta animasi dikurangi
/// (`MediaQuery.disableAnimations`), layar dirender statis.
class ReciteFinishScreen extends StatelessWidget {
  const ReciteFinishScreen({
    super.key,
    required this.surahName,
    required this.versesDone,
    required this.totalVerses,
    required this.accuracyPercent,
    required this.peekCount,
    required this.result,
    required this.surahComplete,
    required this.onContinue,
    required this.onPickSurah,
    required this.onRepeat,
  });

  final String surahName;
  final int versesDone;
  final int totalVerses;
  final int accuracyPercent;
  final int peekCount;
  final RecordResult result;
  final bool surahComplete;
  final VoidCallback onContinue;
  final VoidCallback onPickSurah;
  final VoidCallback onRepeat;

  static const celebrationKey = Key('recite_finish_celebration_scale');
  static const xpKey = Key('recite_finish_xp_scale');

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final animate = !MediaQuery.of(context).disableAnimations;
    final ink = QuranTokens.inkColor(dark);
    final muted = QuranTokens.textMuted(dark);
    final title = surahComplete
        ? 'Surah $surahName selesai'
        : 'Latihan hari ini tersimpan';
    final praise = accuracyPercent >= 90
        ? 'Bacaanmu sudah rapi hari ini.'
        : 'Terus berlatih, ayat ini bisa dicoba lagi.';

    final summary = [
      '$title.',
      '$versesDone dari $totalVerses ayat, akurasi $accuracyPercent persen,',
      '$peekCount kali intip, ${result.xpGained} XP,',
      'streak ${result.newStreak} hari.',
    ].join(' ');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  container: true,
                  label: summary,
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _pop(
                          animate: animate,
                          scaleKey: celebrationKey,
                          child: _Celebration(dark: dark),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: QuranTokens.poppins(
                            const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ).copyWith(color: ink),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          praise,
                          textAlign: TextAlign.center,
                          style: QuranTokens.poppins(
                            QuranTokens.tsVerseTranslation,
                          ).copyWith(color: muted),
                        ),
                        const SizedBox(height: 20),
                        _stats(dark: dark, animate: animate),
                        if (result.streakIncreased ||
                            result.goalJustReached ||
                            result.leveledUp) ...[
                          const SizedBox(height: 12),
                          _milestones(dark: dark),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: const Text('Lanjut'),
                  style: FilledButton.styleFrom(
                    backgroundColor: QuranTokens.activeBg(dark),
                    foregroundColor: ink,
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    textStyle: QuranTokens.poppins(
                      const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: QuranTokens.border(dark)),
                    ),
                  ),
                ),
                if (surahComplete) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onRepeat,
                    icon: const Icon(Icons.replay_rounded, size: 20),
                    label: const Text('Ulangi surah'),
                    style: _secondary(dark),
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onPickSurah,
                  icon: const Icon(Icons.menu_book_outlined, size: 20),
                  label: const Text('Pilih surah lain'),
                  style: _secondary(dark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _secondary(bool dark) => OutlinedButton.styleFrom(
    foregroundColor: QuranTokens.inkColor(dark),
    side: BorderSide(color: QuranTokens.border(dark)),
    minimumSize: const Size.fromHeight(52),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    textStyle: QuranTokens.poppins(
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );

  /// Skala + fade sekali jalan (0.92 → 1.0). Tanpa animasi bila diminta sistem.
  Widget _pop({
    required bool animate,
    required Key scaleKey,
    required Widget child,
  }) {
    if (!animate) {
      return Transform.scale(key: scaleKey, scale: 1, child: child);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(
          key: scaleKey,
          scale: 0.92 + 0.08 * t,
          child: child,
        ),
      ),
      child: child,
    );
  }

  Widget _stats({required bool dark, required bool animate}) {
    Widget tile({
      required String label,
      required String value,
      IconData? icon,
      Color? iconColor,
      Key? valueKey,
    }) {
      final valueText = Text(
        value,
        style: QuranTokens.poppins(
          const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ).copyWith(color: QuranTokens.inkColor(dark)),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: QuranTokens.poppins(
                    QuranTokens.tsLastReadSub,
                  ).copyWith(color: QuranTokens.textMuted(dark)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          if (valueKey == null)
            valueText
          else
            _pop(animate: animate, scaleKey: valueKey, child: valueText),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: QuranTokens.surfaceAlt(dark),
        border: Border.all(color: QuranTokens.border(dark)),
        borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
        boxShadow: QuranTokens.cardShadow(dark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: tile(
                  label: 'Ayat selesai',
                  value: '$versesDone dari $totalVerses',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: tile(
                  label: 'Akurasi',
                  value: '$accuracyPercent%',
                  icon: Icons.track_changes_rounded,
                  iconColor: QuranTokens.correct(dark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: tile(
                  label: 'Kali intip',
                  value: '$peekCount',
                  icon: Icons.visibility_outlined,
                  iconColor: QuranTokens.textMuted(dark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: tile(
                  label: 'XP didapat',
                  value: '+${result.xpGained} XP',
                  icon: Icons.bolt_rounded,
                  iconColor: QuranTokens.xp(dark),
                  valueKey: xpKey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: QuranTokens.border(dark)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 18,
                color: QuranTokens.streak(dark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Streak',
                  style: QuranTokens.poppins(
                    QuranTokens.tsLastReadSub,
                  ).copyWith(color: QuranTokens.textMuted(dark)),
                ),
              ),
              Text(
                '${result.newStreak} hari',
                style: QuranTokens.poppins(QuranTokens.tsSurahName).copyWith(
                  color: QuranTokens.inkColor(dark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _milestones({required bool dark}) {
    Widget line(IconData icon, Color color, String text, {String? value}) =>
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: QuranTokens.poppins(
                  QuranTokens.tsSurahName,
                ).copyWith(color: QuranTokens.inkColor(dark)),
              ),
            ),
            if (value != null)
              Text(
                value,
                style: QuranTokens.poppins(
                  QuranTokens.tsSurahName,
                ).copyWith(color: color, fontWeight: FontWeight.w600),
              ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.streakIncreased)
          line(
            Icons.local_fire_department_rounded,
            QuranTokens.streak(dark),
            'Streak naik',
            value: '${result.newStreak} hari',
          ),
        if (result.goalJustReached) ...[
          if (result.streakIncreased) const SizedBox(height: 8),
          line(
            Icons.flag_rounded,
            QuranTokens.correct(dark),
            'Target hari ini tercapai',
          ),
        ],
        if (result.leveledUp) ...[
          if (result.streakIncreased || result.goalJustReached)
            const SizedBox(height: 8),
          line(
            Icons.auto_awesome_rounded,
            QuranTokens.xp(dark),
            'Level naik ke ${result.newLevel}',
          ),
        ],
      ],
    );
  }
}

/// Bulan sabit + buku kecil, digambar sendiri. Tanpa aset, tanpa maskot.
class _Celebration extends StatelessWidget {
  const _Celebration({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: 96,
        child: CustomPaint(
          painter: _CelebrationPainter(
            halo: QuranTokens.activeBg(dark),
            crescent: QuranTokens.brandColor(dark),
            book: QuranTokens.correct(dark),
            page: QuranTokens.surfaceAlt(dark),
            accent: QuranTokens.xp(dark),
          ),
        ),
      ),
    );
  }
}

class _CelebrationPainter extends CustomPainter {
  const _CelebrationPainter({
    required this.halo,
    required this.crescent,
    required this.book,
    required this.page,
    required this.accent,
  });

  final Color halo;
  final Color crescent;
  final Color book;
  final Color page;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final fill = Paint()..isAntiAlias = true;

    canvas.drawCircle(c, r, fill..color = halo);

    // Bulan sabit: satu lingkaran penuh dikurangi lingkaran kedua.
    final outer = Path()
      ..addOval(Rect.fromCircle(center: c.translate(-2, -6), radius: r * 0.44));
    final bite = Path()
      ..addOval(
        Rect.fromCircle(
          center: c.translate(r * 0.20, -r * 0.30),
          radius: r * 0.38,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, bite),
      fill..color = crescent,
    );

    // Bintang kecil penanda momen.
    canvas.drawCircle(
      c.translate(r * 0.52, -r * 0.46),
      r * 0.075,
      fill..color = accent,
    );

    // Buku: satu kotak membulat, satu garis punggung, dua garis halaman.
    final bookRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: c.translate(-r * 0.02, r * 0.42),
        width: r * 0.78,
        height: r * 0.46,
      ),
      Radius.circular(r * 0.10),
    );
    canvas.drawRRect(bookRect, fill..color = book);

    final line = Paint()
      ..isAntiAlias = true
      ..color = page
      ..strokeWidth = math.max(1.5, r * 0.05)
      ..strokeCap = StrokeCap.round;

    final spineX = bookRect.center.dx + r * 0.10;
    canvas.drawLine(
      Offset(spineX, bookRect.top + r * 0.09),
      Offset(spineX, bookRect.bottom - r * 0.09),
      line,
    );
    for (var i = 0; i < 2; i++) {
      final y = bookRect.top + r * 0.15 + i * r * 0.13;
      canvas.drawLine(
        Offset(bookRect.left + r * 0.12, y),
        Offset(spineX - r * 0.08, y),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter old) =>
      old.halo != halo ||
      old.crescent != crescent ||
      old.book != book ||
      old.page != page ||
      old.accent != accent;
}
