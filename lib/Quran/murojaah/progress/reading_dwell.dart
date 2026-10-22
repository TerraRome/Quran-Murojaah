import 'package:flutter/material.dart';

import '../progress/activity_entry.dart';
import '../progress/reading_log_recorder.dart';

/// Pembungkus satu item yang mungkin "dibaca": menandai masuk/keluar layar ke
/// [ReadingLogRecorder] selama widget ini hidup di pohon.
///
/// Dipakai untuk ayat di halaman surah. `ListView.builder` hanya membangun item
/// di dekat viewport, jadi hidupnya widget ≈ item benar-benar tampil.
class ReadingDwell extends StatefulWidget {
  const ReadingDwell({
    super.key,
    required this.recorder,
    required this.itemKey,
    required this.child,
    this.surahNumber = ActivityEntry.noSurah,
    this.verse = 1,
    this.refId,
  });

  final ReadingLogRecorder recorder;
  final String itemKey;
  final int surahNumber;
  final int verse;
  final String? refId;
  final Widget child;

  @override
  State<ReadingDwell> createState() => _ReadingDwellState();
}

class _ReadingDwellState extends State<ReadingDwell> {
  void _enter() {
    widget.recorder.enter(
      widget.itemKey,
      surahNumber: widget.surahNumber,
      verse: widget.verse,
      refId: widget.refId,
    );
  }

  @override
  void initState() {
    super.initState();
    _enter();
    widget.recorder.addListener(_onRecorder);
  }

  @override
  void didUpdateWidget(ReadingDwell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recorder != widget.recorder) {
      oldWidget.recorder
        ..removeListener(_onRecorder)
        ..leave(oldWidget.itemKey);
      widget.recorder.addListener(_onRecorder);
      _enter();
      return;
    }
    if (oldWidget.itemKey != widget.itemKey) {
      widget.recorder.leave(oldWidget.itemKey);
      _enter();
    }
  }

  /// Resume setelah pause: hitungan dwell dimulai lagi dari nol.
  void _onRecorder() => _enter();

  @override
  void dispose() {
    widget.recorder
      ..removeListener(_onRecorder)
      ..leave(widget.itemKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Tombol "Tandai sudah dibaca" — ikon + label, tinggi minimal 48 px.
///
/// Diletakkan sebagai anak layout (bukan overlay) supaya tidak pernah menutupi
/// konten. Label memakai [Expanded] sehingga membungkus ke baris kedua pada
/// layar sempit atau teks diperbesar, bukan terpotong.
class MarkReadButton extends StatelessWidget {
  const MarkReadButton({
    super.key,
    required this.onPressed,
    this.label = 'Tandai sudah dibaca',
    this.icon = Icons.done_all_rounded,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
