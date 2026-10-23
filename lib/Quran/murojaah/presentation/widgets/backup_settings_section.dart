import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/quran_tokens.dart';
import '../../backup/backup_controller.dart';
import '../../backup/backup_document.dart';
import '../../backup/backup_sharer.dart';
import '../../progress/progress_controller.dart';
import '../../reminder/reminder_controller.dart';

/// Bagian "Cadangan data" di halaman Pengaturan: ekspor satu berkas JSON,
/// impor dengan gabung berdasarkan id.
///
/// Impor selalu dua langkah — periksa, lalu konfirmasi — supaya data rusak
/// berhenti sebelum menyentuh log.
class BackupSettingsSection extends StatefulWidget {
  const BackupSettingsSection({
    super.key,
    required this.progress,
    required this.reminder,
    this.sharer = const SharePlusBackupSharer(),
  });

  final MurojaahProgressController progress;
  final MurojaahReminder reminder;
  final BackupSharer sharer;

  @override
  State<BackupSettingsSection> createState() => _BackupSettingsSectionState();
}

class _BackupSettingsSectionState extends State<BackupSettingsSection> {
  bool _busy = false;

  MurojaahBackup get _backup =>
      MurojaahBackup(progress: widget.progress, reminder: widget.reminder);

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await widget.sharer.share(_backup.exportJson());
      if (!mounted) return;
      _snack(
        ok
            ? 'Berkas cadangan disiapkan.'
            : 'Berbagi dibatalkan. Tidak ada yang berubah.',
      );
    } catch (_) {
      if (!mounted) return;
      _snack('Cadangan gagal dibuat. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    if (_busy) return;
    try {
      await Clipboard.setData(ClipboardData(text: _backup.exportJson()));
      if (!mounted) return;
      _snack('Cadangan disalin.');
    } catch (_) {
      if (!mounted) return;
      _snack('Gagal menyalin. Coba Ekspor data.');
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => const _ImportTextDialog(),
    );
    if (raw == null || !mounted) return;

    final parsed = _backup.parse(raw);
    if (parsed is! BackupOk) {
      await _showMessage(
        title: 'Berkas tidak bisa dipakai',
        body: (parsed as BackupInvalid).message,
      );
      return;
    }

    final document = parsed.document;
    final fresh = _backup.countNew(document);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Impor cadangan?'),
        content: Text(
          '${importSummary(fresh)}\n\n'
          'Target harian dan pengaturan pengingat ikut dipulihkan. Data yang '
          'sudah ada tidak ditimpa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Impor'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final added = await _backup.import(document);
      if (!mounted) return;
      _snack('Selesai — $added entri baru ditambahkan.');
    } catch (_) {
      if (!mounted) return;
      _snack('Impor gagal. Data lama tidak berubah.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showMessage({required String title, required String body}) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cadangan data',
          style: QuranTokens.poppins(
            QuranTokens.tsSurahName,
          ).copyWith(color: QuranTokens.inkColor(dark)),
        ),
        const SizedBox(height: 8),
        Material(
          color: QuranTokens.surfaceAlt(dark),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: QuranTokens.border(dark)),
            borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                minVerticalPadding: 12,
                leading: Icon(
                  Icons.ios_share,
                  color: QuranTokens.brandColor(dark),
                ),
                title: Text(
                  'Ekspor data',
                  style: QuranTokens.poppins(
                    QuranTokens.tsSurahName,
                  ).copyWith(color: QuranTokens.inkColor(dark)),
                ),
                subtitle: Text(
                  'Simpan log murojaah dan pengaturan sebagai berkas JSON.',
                  style: QuranTokens.poppins(
                    QuranTokens.tsSurahMeta,
                  ).copyWith(color: QuranTokens.textMuted(dark)),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _export,
              ),
              const Divider(height: 1),
              ListTile(
                minVerticalPadding: 12,
                leading: Icon(
                  Icons.copy_all_outlined,
                  color: QuranTokens.brandColor(dark),
                ),
                title: Text(
                  'Salin cadangan',
                  style: QuranTokens.poppins(
                    QuranTokens.tsSurahName,
                  ).copyWith(color: QuranTokens.inkColor(dark)),
                ),
                subtitle: Text(
                  'Salin isi JSON ke papan klip, lalu tempel di catatan atau '
                  'aplikasi pesan.',
                  style: QuranTokens.poppins(
                    QuranTokens.tsSurahMeta,
                  ).copyWith(color: QuranTokens.textMuted(dark)),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _copy,
              ),
              const Divider(height: 1),
              ListTile(
                minVerticalPadding: 12,
                leading: Icon(
                  Icons.file_download_outlined,
                  color: QuranTokens.brandColor(dark),
                ),
                title: Text(
                  'Impor data',
                  style: QuranTokens.poppins(
                    QuranTokens.tsSurahName,
                  ).copyWith(color: QuranTokens.inkColor(dark)),
                ),
                subtitle: Text(
                  'Tempel isi berkas cadangan. Entri baru ditambahkan, data '
                  'lama tidak ditimpa.',
                  style: QuranTokens.poppins(
                    QuranTokens.tsSurahMeta,
                  ).copyWith(color: QuranTokens.textMuted(dark)),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _import,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dialog tempel-teks. Mengembalikan isi mentah, atau null bila dibatalkan.
///
/// `file_picker` sengaja tidak dipakai: satu dependensi native baru hanya untuk
/// membuka berkas tidak sepadan. Tempel dari aplikasi mana pun tetap bekerja.
class _ImportTextDialog extends StatefulWidget {
  const _ImportTextDialog();

  @override
  State<_ImportTextDialog> createState() => _ImportTextDialogState();
}

class _ImportTextDialogState extends State<_ImportTextDialog> {
  final _controller = TextEditingController();
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final can = _controller.text.trim().isNotEmpty;
      if (can != _canSubmit) setState(() => _canSubmit = can);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Impor cadangan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tempel seluruh isi berkas cadangan (diawali "{") ke kolom ini.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 5,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '{ "app": "quran-murojaah", ... }',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _canSubmit
              ? () => Navigator.of(context).pop(_controller.text)
              : null,
          child: const Text('Periksa'),
        ),
      ],
    );
  }
}
