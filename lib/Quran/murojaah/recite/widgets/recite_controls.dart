import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../recite_murojaah_service.dart';

/// Status dalam kalimat biasa, bukan istilah mesin.
({String text, String hint, IconData icon, Color color}) _statusStyle(
  ReciteMurojaahStatus status,
  String? message,
  bool dark,
) {
  final brand = QuranTokens.brandColor(dark);
  final grey = QuranTokens.textMuted(dark);
  return switch (status) {
    ReciteMurojaahStatus.idle => (
      text: 'Belum mulai',
      hint: 'Tekan tombol mikrofon di bawah.',
      icon: Icons.mic_none,
      color: grey,
    ),
    ReciteMurojaahStatus.preparing => (
      text: 'Menyiapkan…',
      hint: 'Sebentar lagi siap.',
      icon: Icons.hourglass_top,
      color: grey,
    ),
    ReciteMurojaahStatus.downloadingModel => (
      text: 'Mengunduh suara…',
      hint: 'Perlu internet. Hanya sekali.',
      icon: Icons.cloud_download_outlined,
      color: grey,
    ),
    ReciteMurojaahStatus.ready => (
      text: 'Siap mendengarkan',
      hint: 'Tekan mikrofon, lalu mulai membaca.',
      icon: Icons.mic,
      color: brand,
    ),
    ReciteMurojaahStatus.listening => (
      text: 'Sedang mendengarkan',
      hint: 'Baca dengan suara biasa.',
      icon: Icons.graphic_eq,
      color: brand,
    ),
    ReciteMurojaahStatus.error => (
      text: message ?? 'Ada masalah kecil. Coba lagi.',
      hint: 'Tekan tombol di bawah untuk mencoba lagi.',
      icon: Icons.info_outline,
      color: QuranTokens.wrong(dark),
    ),
  };
}

/// Status bacaan: satu baris jelas + petunjuk satu kalimat.
class ReciteStatusChip extends StatelessWidget {
  const ReciteStatusChip({
    super.key,
    required this.status,
    required this.message,
    required this.dark,
    this.showHint = false,
  });

  final ReciteMurojaahStatus status;
  final String? message;
  final bool dark;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final s = _statusStyle(status, message, dark);
    return Semantics(
      liveRegion: true,
      label: 'Status: ${s.text}. ${s.hint}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: s.color.withValues(alpha: dark ? 0.16 : 0.09),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: s.color.withValues(alpha: 0.28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(s.icon, size: 18, color: s.color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    s.text,
                    maxLines: 2,
                    style: QuranTokens.poppins(
                      TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: s.color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (showHint) ...[
              const SizedBox(height: 4),
              Text(
                s.hint,
                style: QuranTokens.poppins(
                  TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: QuranTokens.textMuted(dark),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Progress unduhan model (0..1).
class ReciteDownloadBar extends StatelessWidget {
  const ReciteDownloadBar({
    super.key,
    required this.progress,
    required this.dark,
  });

  final ValueNotifier<double> progress;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, value, _) {
        final percent = (value.clamp(0.0, 1.0) * 100).round();
        return Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: QuranTokens.border(dark),
                  valueColor: AlwaysStoppedAnimation(
                    QuranTokens.brandColor(dark),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$percent%',
              style: QuranTokens.poppins(
                TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: QuranTokens.textMuted(dark),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Aksi utama: mikrofon besar + label yang berubah sesuai keadaan.
class ReciteMicButton extends StatelessWidget {
  const ReciteMicButton({
    super.key,
    required this.listening,
    required this.enabled,
    required this.dark,
    required this.onTap,
  });

  final bool listening;
  final bool enabled;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = QuranTokens.brandColor(dark);
    final label = listening ? 'Berhenti' : 'Mulai membaca';
    return Semantics(
      button: true,
      enabled: enabled,
      label: listening ? 'Berhenti membaca' : 'Mulai membaca',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: enabled ? onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? brand : brand.withValues(alpha: 0.35),
                boxShadow: [
                  BoxShadow(
                    color: brand.withValues(alpha: listening ? 0.40 : 0.16),
                    blurRadius: listening ? 24 : 10,
                    spreadRadius: listening ? 7 : 1,
                  ),
                ],
              ),
              child: Center(
                child: listening
                    ? Icon(
                        Icons.stop_rounded,
                        color: QuranTokens.onPrimaryColor(dark),
                        size: 30,
                      )
                    : Icon(
                        Icons.mic,
                        color: QuranTokens.onPrimaryColor(dark).withValues(
                          alpha: enabled ? 1 : 0.6,
                        ),
                        size: 28,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: QuranTokens.poppins(
              TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: enabled
                    ? QuranTokens.inkColor(dark)
                    : QuranTokens.textMuted(dark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol sekunder berlabel: ikon + teks, area ketuk ≥ 48.
class ReciteActionButton extends StatelessWidget {
  const ReciteActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.dark,
    this.onTap,
    this.urgency,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool dark;
  final VoidCallback? onTap;

  /// Warna aksen khusus (mis. merah saat perlu diulang).
  final Color? urgency;

  /// Versi kecil untuk baris aksi tambahan.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = !enabled
        ? QuranTokens.textMuted(dark).withValues(alpha: 0.42)
        : urgency ?? QuranTokens.textMuted(dark);
    final content = compact
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: QuranTokens.poppins(
                  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: QuranTokens.poppins(
                  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }
}
