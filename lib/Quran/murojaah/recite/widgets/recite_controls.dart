import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../recite_murojaah_service.dart';

/// Chip status ringkas: menyiapkan / unduh model / siap / mendengarkan / error.
class ReciteStatusChip extends StatelessWidget {
  const ReciteStatusChip({
    super.key,
    required this.status,
    required this.message,
    required this.dark,
  });

  final ReciteMurojaahStatus status;
  final String? message;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color, IconData icon) = switch (status) {
      ReciteMurojaahStatus.idle => (
          'Siap dimulai',
          QuranTokens.secondaryColor(dark),
          Icons.mic_none,
        ),
      ReciteMurojaahStatus.preparing => (
          'Menyiapkan mesin bacaan…',
          QuranTokens.secondaryColor(dark),
          Icons.settings_input_antenna,
        ),
      ReciteMurojaahStatus.downloadingModel => (
          'Mengunduh model bacaan…',
          QuranTokens.secondaryColor(dark),
          Icons.cloud_download_outlined,
        ),
      ReciteMurojaahStatus.ready => (
          'Siap mendengarkan',
          QuranTokens.brandColor(dark),
          Icons.mic,
        ),
      ReciteMurojaahStatus.listening => (
          'Mendengarkan bacaan…',
          QuranTokens.brandColor(dark),
          Icons.graphic_eq,
        ),
      ReciteMurojaahStatus.error => (
          message ?? 'Terjadi kesalahan.',
          Colors.red.shade400,
          Icons.error_outline,
        ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: QuranTokens.poppins(
              TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
            ),
          ),
        ),
      ],
    );
  }
}

/// Progress unduhan model (0..1).
class ReciteDownloadBar extends StatelessWidget {
  const ReciteDownloadBar({super.key, required this.progress, required this.dark});

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
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: QuranTokens.divider(dark),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: QuranTokens.secondaryColor(dark),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Tombol mikrofon bulat — aksi utama halaman.
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
    return Semantics(
      button: true,
      label: listening ? 'Berhenti mendengarkan' : 'Mulai mendengarkan',
      child: GestureDetector(
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
                color: brand.withValues(alpha: listening ? 0.42 : 0.18),
                blurRadius: listening ? 22 : 10,
                spreadRadius: listening ? 6 : 1,
              ),
            ],
          ),
          child: Center(
            child: listening
                ? const Icon(Icons.stop_rounded, color: Colors.white, size: 30)
                : Icon(
                    Icons.mic,
                    color: Colors.white.withValues(alpha: enabled ? 1 : 0.6),
                    size: 28,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Tombol sekunder berlabel (retry / reset).
class ReciteIconAction extends StatelessWidget {
  const ReciteIconAction({
    super.key,
    required this.icon,
    required this.label,
    required this.dark,
    this.onTap,
    this.urgency,
  });

  final IconData icon;
  final String label;
  final bool dark;
  final VoidCallback? onTap;

  /// Warna aksen khusus (mis. merah saat perlu diulang).
  final Color? urgency;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? QuranTokens.secondaryColor(dark).withValues(alpha: 0.4)
        : urgency ?? QuranTokens.secondaryColor(dark);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: QuranTokens.poppins(
                  TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
