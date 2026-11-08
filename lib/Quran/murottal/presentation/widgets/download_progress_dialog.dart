import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../application/download_controller.dart';

/// Dialog modal konfirmasi download + progress bar murottal.
///
/// Alur:
/// 1. [DownloadReady]     → tampilkan info ukuran file + tombol Download
/// 2. [DownloadInProgress] → tampilkan progress bar + estimasi waktu
/// 3. [DownloadCompleted]  → tutup otomatis
/// 4. [DownloadError]      → tampilkan pesan error + tombol Coba Lagi
class DownloadProgressDialog extends StatelessWidget {
  const DownloadProgressDialog({
    super.key,
    required this.controller,
    required this.surahName,
    required this.onConfirm,
    required this.onCancel,
    this.notice,
  });

  final DownloadController controller;
  final String surahName;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  /// Kalimat pembuka (mis. "Surah ini belum diunduh."), tampil di atas penjelasan.
  final String? notice;

  static Future<void> show({
    required BuildContext context,
    required DownloadController controller,
    required String surahName,
    required VoidCallback onConfirm,
    String? notice,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DownloadProgressDialog(
        controller: controller,
        surahName: surahName,
        onConfirm: onConfirm,
        onCancel: () => Navigator.of(context).pop(),
        notice: notice,
      ),
    );
  }

  /// Alur lengkap: hitung perkiraan ukuran + cek ruang/jaringan, tampilkan
  /// dialog konfirmasi, lalu unduh seluruh ayat surah.
  static Future<void> run({
    required BuildContext context,
    required DownloadController controller,
    required String qariId,
    required int surahNumber,
    required int verseCount,
    required String surahName,
    String? notice,
  }) async {
    await controller.prepare(qariId, verseCount);
    if (!context.mounted) return;
    await show(
      context: context,
      controller: controller,
      surahName: surahName,
      notice: notice,
      onConfirm: () => controller.startDownload(
        qariId: qariId,
        surahNumber: surahNumber,
        verseCount: verseCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DownloadState>(
      valueListenable: controller,
      builder: (context, state, _) {
        // Tutup otomatis saat selesai
        if (state is DownloadCompleted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).pop();
          });
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.download_rounded,
                color: QuranTokens.brandOf(context),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Unduh Murottal',
                  style: QuranTokens.poppins(
                    const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          content: _DialogContent(
            state: state,
            surahName: surahName,
            notice: notice,
          ),
          actions: _buildActions(context, state),
        );
      },
    );
  }

  List<Widget> _buildActions(BuildContext context, DownloadState state) {
    if (state is DownloadReady && state.lowSpace) {
      return [
        TextButton(
          onPressed: onCancel,
          child: Text(
            'Tutup',
            style: QuranTokens.poppins(
              TextStyle(color: QuranTokens.mutedOf(context)),
            ),
          ),
        ),
      ];
    }

    if (state is DownloadReady) {
      return [
        TextButton(
          onPressed: onCancel,
          child: Text(
            'Batal',
            style: QuranTokens.poppins(
              TextStyle(color: QuranTokens.mutedOf(context)),
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: QuranTokens.brandOf(context),
            foregroundColor: QuranTokens.onBrandOf(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: Text(
            state.needsMobileConfirm ? 'Unduh dengan data seluler' : 'Unduh',
            style: QuranTokens.poppins(
              const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ];
    }

    if (state is DownloadInProgress) {
      return [
        TextButton(
          onPressed: () {
            controller.cancelDownload();
            onCancel();
          },
          child: Text(
            'Batalkan',
            style: QuranTokens.poppins(
              TextStyle(color: QuranTokens.mutedOf(context)),
            ),
          ),
        ),
      ];
    }

    if (state is DownloadError) {
      return [
        TextButton(
          onPressed: onCancel,
          child: Text(
            'Tutup',
            style: QuranTokens.poppins(
              TextStyle(color: QuranTokens.mutedOf(context)),
            ),
          ),
        ),
        FilledButton(
          onPressed: onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: QuranTokens.brandOf(context),
            foregroundColor: QuranTokens.onBrandOf(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Coba Lagi',
            style: QuranTokens.poppins(
              const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ];
    }

    return [];
  }
}

class _DialogContent extends StatelessWidget {
  const _DialogContent({
    required this.state,
    required this.surahName,
    this.notice,
  });

  final DownloadState state;
  final String surahName;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      DownloadCheckingSize() => _CheckingSizeContent(surahName: surahName),
      DownloadReady() => _ReadyContent(
          surahName: surahName, state: state as DownloadReady, notice: notice),
      DownloadInProgress() =>
        _ProgressContent(state: state as DownloadInProgress),
      DownloadCompleted() => _CompletedContent(surahName: surahName),
      DownloadError(:final message) => _ErrorContent(message: message),
      _ => const SizedBox.shrink(),
    };
  }
}

class _CheckingSizeContent extends StatelessWidget {
  const _CheckingSizeContent({required this.surahName});
  final String surahName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        CircularProgressIndicator(color: QuranTokens.brandOf(context)),
        const SizedBox(height: 16),
        Text(
          'Memeriksa ruang penyimpanan...',
          style: QuranTokens.poppins(
            TextStyle(fontSize: 14, color: QuranTokens.mutedOf(context)),
          ),
        ),
      ],
    );
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.surahName,
    required this.state,
    this.notice,
  });
  final String surahName;
  final DownloadReady state;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${notice == null ? '' : '$notice '}Simpan audio murottal $surahName '
          'ke perangkat untuk diputar offline.',
          style: QuranTokens.poppins(
            const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        const SizedBox(height: 16),
        _InfoRow(
          icon: Icons.storage_rounded,
          label: 'Perkiraan ukuran',
          value: state.fileSizeLabel,
        ),
        if (state.lowSpace) ...[
          const SizedBox(height: 12),
          Text(
            'Ruang penyimpanan tidak cukup. Kosongkan ruang di perangkat, '
            'lalu coba lagi.',
            style: QuranTokens.poppins(TextStyle(
                fontSize: 13, color: QuranTokens.wrongOf(context))),
          ),
        ] else if (state.needsMobileConfirm) ...[
          const SizedBox(height: 12),
          Text(
            'Kamu memakai data seluler. Unduhan sebesar ini bisa menghabiskan '
            'kuota.',
            style: QuranTokens.poppins(TextStyle(
                fontSize: 13, color: QuranTokens.wrongOf(context))),
          ),
        ],
        const SizedBox(height: 8),
        const _InfoRow(
          icon: Icons.wifi_off_rounded,
          label: 'Setelah diunduh',
          value: 'Offline ready',
        ),
      ],
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({required this.state});
  final DownloadInProgress state;

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;
    final percent = state.percent;
    final etaLabel = state.etaLabel;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mengunduh...',
              style: QuranTokens.poppins(
                TextStyle(fontSize: 13, color: QuranTokens.mutedOf(context)),
              ),
            ),
            Text(
              percent != null ? '$percent%' : '',
              style: QuranTokens.poppins(
                TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: QuranTokens.brandOf(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: QuranTokens.border(
              Theme.of(context).brightness == Brightness.dark,
            ),
            valueColor: AlwaysStoppedAnimation<Color>(
              QuranTokens.brandOf(context),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              state.receivedLabel,
              style: QuranTokens.poppins(
                TextStyle(fontSize: 12, color: QuranTokens.mutedOf(context)),
              ),
            ),
            if (etaLabel.isNotEmpty)
              Text(
                'Sisa: $etaLabel',
                style: QuranTokens.poppins(
                  TextStyle(fontSize: 12, color: QuranTokens.mutedOf(context)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CompletedContent extends StatelessWidget {
  const _CompletedContent({required this.surahName});
  final String surahName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.check_circle_rounded,
          color: QuranTokens.correctOf(context),
          size: 32,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '$surahName berhasil diunduh.',
            style: QuranTokens.poppins(const TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.error_outline_rounded,
          color: QuranTokens.wrongOf(context),
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: QuranTokens.poppins(
              TextStyle(
                fontSize: 13,
                color: QuranTokens.wrongOf(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: QuranTokens.mutedOf(context)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: QuranTokens.poppins(
            TextStyle(fontSize: 13, color: QuranTokens.mutedOf(context)),
          ),
        ),
        Text(
          value,
          style: QuranTokens.poppins(
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
