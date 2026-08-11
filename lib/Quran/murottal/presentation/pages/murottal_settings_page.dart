import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/datasources/audio_local_datasource.dart';
import '../../../data/quran_tokens.dart';
import '../../../domain/entities/qari.dart';
import '../../../murottal/application/qari_store.dart';
import '../../../presentation/widgets/quran_status_bar.dart';
import '../../../presentation/widgets/quran_theme_scope.dart';
import '../../../presentation/widgets/quran_top_bar.dart';

/// Halaman pengaturan Murottal:
/// - Pilih qari aktif
/// - Daftar file audio tersimpan + hapus manual
/// - Toggle dark mode
class MurottalSettingsPage extends StatefulWidget {
  const MurottalSettingsPage({super.key});

  @override
  State<MurottalSettingsPage> createState() => _MurottalSettingsPageState();
}

class _MurottalSettingsPageState extends State<MurottalSettingsPage> {
  final AudioLocalDataSource _local = AudioLocalDataSourceImpl();

  QariStore? _qariStore;
  Qari _selectedQari = Qari.defaultQari;
  List<LocalAudioInfo> _downloads = [];
  int _totalBytes = 0;
  bool _loadingDownloads = true;

  @override
  void initState() {
    super.initState();
    _initPrefs();
    _loadDownloads();
  }

  Future<void> _initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final store = QariStore(prefs);
    setState(() {
      _qariStore = store;
      _selectedQari = store.getSelectedQari();
    });
  }

  Future<void> _loadDownloads() async {
    setState(() => _loadingDownloads = true);
    final files = await _local.listDownloaded();
    final total = await _local.getTotalStorageUsed();
    if (!mounted) return;
    setState(() {
      _downloads = files;
      _totalBytes = total;
      _loadingDownloads = false;
    });
  }

  Future<void> _selectQari(Qari qari) async {
    await _qariStore?.setSelectedQari(qari);
    if (!mounted) return;
    setState(() => _selectedQari = qari);
  }

  Future<void> _deleteFile(LocalAudioInfo info) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dark = QuranThemeScope.darkOf(context);
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: QuranTokens.surface(dark),
          title: Text(
            'Hapus File',
            style: QuranTokens.poppins(
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ).copyWith(color: QuranTokens.inkColor(dark)),
          ),
          content: Text(
            'Hapus audio surah ${_surahLabel(info.surahNumber)} — ${info.fileSizeLabel}?',
            style: QuranTokens.poppins(const TextStyle(fontSize: 14))
                .copyWith(color: QuranTokens.secondaryColor(dark)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Batal',
                  style: QuranTokens.poppins(
                      const TextStyle(color: QuranTokens.secondary))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Hapus',
                  style: QuranTokens.poppins(
                      const TextStyle(fontWeight: FontWeight.w600))),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await _local.delete(info.qariId, info.surahNumber);
      await _loadDownloads();
    }
  }

  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dark = QuranThemeScope.darkOf(context);
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: QuranTokens.surface(dark),
          title: Text(
            'Hapus Semua File',
            style: QuranTokens.poppins(
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ).copyWith(color: QuranTokens.inkColor(dark)),
          ),
          content: Text(
            'Hapus semua ${_downloads.length} file audio tersimpan ($_totalSizeLabel)?',
            style: QuranTokens.poppins(const TextStyle(fontSize: 14))
                .copyWith(color: QuranTokens.secondaryColor(dark)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Batal',
                  style: QuranTokens.poppins(
                      const TextStyle(color: QuranTokens.secondary))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Hapus Semua',
                  style: QuranTokens.poppins(
                      const TextStyle(fontWeight: FontWeight.w600))),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await _local.deleteAll();
      await _loadDownloads();
    }
  }

  String _surahLabel(int number) => 'Q.S. $number';

  String get _totalSizeLabel {
    if (_totalBytes < 1024 * 1024) {
      return '${(_totalBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(_totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return QuranStatusBar(
      dark: dark,
      child: Scaffold(
        backgroundColor: QuranTokens.background(dark),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              QuranTopBar(
                title: 'Murottal',
                titleColor: QuranTokens.brandColor(dark),
                leading: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  color: QuranTokens.inkColor(dark),
                ),
                onThemeToggle: () => QuranThemeScope.toggleDark(context),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  children: [
                    // --- Pilih Qari ---
                    _SectionTitle(dark: dark, title: 'Qari'),
                    const SizedBox(height: 12),
                    ...Qari.all.map(
                      (qari) => _QariTile(
                        qari: qari,
                        isSelected: _selectedQari == qari,
                        dark: dark,
                        onTap: () => _selectQari(qari),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // --- File Tersimpan ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SectionTitle(dark: dark, title: 'File Tersimpan'),
                        if (_downloads.isNotEmpty)
                          TextButton.icon(
                            onPressed: _deleteAll,
                            icon: const Icon(Icons.delete_sweep_rounded,
                                size: 16, color: Colors.red),
                            label: Text(
                              'Hapus Semua',
                              style: QuranTokens.poppins(
                                const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_loadingDownloads)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                              color: QuranTokens.primary),
                        ),
                      )
                    else if (_downloads.isEmpty)
                      _EmptyDownloads(dark: dark)
                    else ...[
                      // Total storage info
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: QuranTokens.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.storage_rounded,
                                size: 16, color: QuranTokens.primary),
                            const SizedBox(width: 8),
                            Text(
                              '${_downloads.length} file · $_totalSizeLabel',
                              style: QuranTokens.poppins(
                                const TextStyle(
                                    fontSize: 13,
                                    color: QuranTokens.primary,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._downloads.map(
                        (info) => _DownloadTile(
                          info: info,
                          dark: dark,
                          onDelete: () => _deleteFile(info),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.dark, required this.title});
  final bool dark;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: QuranTokens.poppins(
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            letterSpacing: 0.6),
      ).copyWith(color: QuranTokens.secondaryColor(dark)),
    );
  }
}

class _QariTile extends StatelessWidget {
  const _QariTile({
    required this.qari,
    required this.isSelected,
    required this.dark,
    required this.onTap,
  });
  final Qari qari;
  final bool isSelected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? QuranTokens.primary.withValues(alpha: 0.08)
              : QuranTokens.surface(dark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? QuranTokens.primary
                : QuranTokens.divider(dark),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? QuranTokens.primary
                    : QuranTokens.divider(dark),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  qari.id,
                  style: QuranTokens.poppins(
                    TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : QuranTokens.secondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                qari.name,
                style: QuranTokens.poppins(
                  TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? QuranTokens.primary
                        : QuranTokens.inkColor(dark),
                  ),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: QuranTokens.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.info,
    required this.dark,
    required this.onDelete,
  });
  final LocalAudioInfo info;
  final bool dark;
  final VoidCallback onDelete;

  String get _qariName {
    final qari = Qari.all
        .where((q) => q.id == info.qariId)
        .firstOrNull;
    return qari?.name ?? info.qariId;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: QuranTokens.surface(dark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: QuranTokens.divider(dark)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: QuranTokens.gradientEnd.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.audio_file_rounded,
                color: QuranTokens.gradientEnd, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Surah ${info.surahNumber.toString().padLeft(3, '0')}',
                  style: QuranTokens.poppins(
                    const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ).copyWith(color: QuranTokens.inkColor(dark)),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_qariName · ${info.fileSizeLabel}',
                  style: QuranTokens.poppins(
                    const TextStyle(fontSize: 12),
                  ).copyWith(color: QuranTokens.secondaryColor(dark)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.red, size: 20),
            tooltip: 'Hapus',
          ),
        ],
      ),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.download_for_offline_outlined,
            size: 48,
            color: QuranTokens.secondaryColor(dark).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada audio tersimpan',
            style: QuranTokens.poppins(
              const TextStyle(fontSize: 14),
            ).copyWith(color: QuranTokens.secondaryColor(dark)),
          ),
          const SizedBox(height: 4),
          Text(
            'Download murottal dari halaman surah',
            style: QuranTokens.poppins(
              const TextStyle(fontSize: 12),
            ).copyWith(
                color: QuranTokens.secondaryColor(dark)
                    .withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}
