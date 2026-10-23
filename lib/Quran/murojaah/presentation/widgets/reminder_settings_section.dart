import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../progress/progress_controller.dart';
import '../../reminder/reminder_controller.dart';
import '../../reminder/reminder_scheduler.dart';

/// Bagian "Pengingat" di halaman Pengaturan.
///
/// Satu saklar, satu pilihan jam, satu baris status izin. Saat izin ditolak,
/// yang muncul penjelasan + jalan ke pengaturan sistem — bukan pesan error.
class ReminderSettingsSection extends StatefulWidget {
  const ReminderSettingsSection({
    super.key,
    required this.reminder,
    required this.progress,
  });

  final MurojaahReminder reminder;
  final MurojaahProgressController progress;

  @override
  State<ReminderSettingsSection> createState() =>
      _ReminderSettingsSectionState();
}

class _ReminderSettingsSectionState extends State<ReminderSettingsSection> {
  bool _busy = false;

  MurojaahReminder get _reminder => widget.reminder;

  @override
  void initState() {
    super.initState();
    if (!_reminder.isLoaded) {
      _reminder.load().then((_) {
        if (!mounted) return;
        final snapshot = widget.progress.snapshot();
        _reminder.sync(
          activeToday: snapshot.activeToday,
          streak: snapshot.streak,
        );
      });
    }
  }

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    if (value && !await _explainPermission()) return;
    setState(() => _busy = true);
    try {
      final snapshot = widget.progress.snapshot();
      await _reminder.sync(
        activeToday: snapshot.activeToday,
        streak: snapshot.streak,
      );
      await _reminder.setEnabled(value);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Penjelasan ramah sebelum dialog izin sistem muncul.
  Future<bool> _explainPermission() async {
    if (_reminder.permission == ReminderPermission.granted) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izinkan notifikasi'),
        content: const Text(
          'Pengingat murojaah dikirim sebagai notifikasi. Kami hanya memakai '
          'satu pengingat sehari, dan berhenti sendiri kalau aplikasi tidak '
          'dibuka beberapa hari.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _pickTime(bool dark) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminder.hour, minute: _reminder.minute),
      helpText: 'Jam pengingat',
    );
    if (picked == null) return;
    await _reminder.setTime(picked.hour, picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: _reminder,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pengingat',
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
                SwitchListTile.adaptive(
                  value: _reminder.enabled,
                  onChanged: _busy ? null : _toggle,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  secondary: Icon(
                    Icons.notifications_active_outlined,
                    color: QuranTokens.brandColor(dark),
                  ),
                  title: Text(
                    'Pengingat harian',
                    style: QuranTokens.poppins(
                      QuranTokens.tsSurahName,
                    ).copyWith(color: QuranTokens.inkColor(dark)),
                  ),
                  subtitle: Text(
                    _reminder.enabled
                        ? 'Aktif — satu notifikasi sehari, izin diberikan.'
                        : _reminder.permission == ReminderPermission.denied
                        ? 'Mati — izin notifikasi belum diberikan.'
                        : 'Mati — tidak ada notifikasi.',
                    style: QuranTokens.poppins(
                      QuranTokens.tsSurahMeta,
                    ).copyWith(color: QuranTokens.textMuted(dark)),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  minVerticalPadding: 12,
                  leading: Icon(
                    Icons.schedule,
                    color: QuranTokens.brandColor(dark),
                  ),
                  title: Text(
                    'Jam pengingat',
                    style: QuranTokens.poppins(
                      QuranTokens.tsSurahName,
                    ).copyWith(color: QuranTokens.inkColor(dark)),
                  ),
                  subtitle: Text(
                    'sekitar ${_reminder.timeLabel}',
                    style: QuranTokens.poppins(
                      QuranTokens.tsSurahMeta,
                    ).copyWith(color: QuranTokens.textMuted(dark)),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickTime(dark),
                ),
                if (_reminder.permission == ReminderPermission.denied) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: QuranTokens.textMuted(dark),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Izin notifikasi belum diberikan. Pengingat tidak '
                            'akan muncul sampai izin dinyalakan di pengaturan '
                            'sistem.',
                            style: QuranTokens.poppins(
                              QuranTokens.tsSurahMeta,
                            ).copyWith(color: QuranTokens.textMuted(dark)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: OutlinedButton.icon(
                      onPressed: _reminder.openSystemSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Buka pengaturan sistem'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
