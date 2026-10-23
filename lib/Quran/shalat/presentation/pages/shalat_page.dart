import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../../presentation/widgets/quran_status_bar.dart';
import '../../../presentation/widgets/quran_theme_scope.dart';
import '../../application/location_provider.dart';
import '../../application/shalat_controller.dart';
import '../../domain/entities/waktu_shalat.dart';
import '../widgets/lokasi_selector_sheet.dart';

/// Halaman jadwal shalat: hari ini + countdown + kalender satu bulan.
class ShalatPage extends StatefulWidget {
  const ShalatPage({super.key, required this.controller});

  final ShalatController controller;

  @override
  State<ShalatPage> createState() => _ShalatPageState();
}

class _ShalatPageState extends State<ShalatPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.init();
  }

  @override
  Widget build(BuildContext context) {
    final dark = QuranThemeScope.darkOf(context);
    return QuranStatusBar(
      dark: dark,
      child: Scaffold(
        backgroundColor: QuranTokens.background(dark),
        body: SafeArea(
          child: ValueListenableBuilder<ShalatState>(
            valueListenable: widget.controller,
            builder: (context, state, _) {
              return switch (state) {
                ShalatLoading() => _buildLoading(dark),
                ShalatNeedLocation() =>
                  _buildNeedLocation(context, state, dark),
                ShalatLoaded() => _buildLoaded(context, state, dark),
                ShalatError() => _buildError(context, state.message, dark),
              };
            },
          ),
        ),
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Widget _buildLoading(bool dark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: QuranTokens.brandColor(dark)),
          const SizedBox(height: 16),
          Text(
            'Memuat jadwal shalat...',
            style: QuranTokens.poppins(QuranTokens.tsSurahMeta)
                .copyWith(color: QuranTokens.secondaryColor(dark)),
          ),
        ],
      ),
    );
  }

  // ── Need location ─────────────────────────────────────────────────────────

  Widget _buildNeedLocation(
      BuildContext context, ShalatNeedLocation state, bool dark) {
    final issue = state.issue;
    final copy = issue == null ? null : copyForIssue(issue);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.location_on_outlined,
            size: 64, color: QuranTokens.brandColor(dark)),
        const SizedBox(height: 16),
        Text(
          copy?.title ?? 'Izinkan Akses Lokasi',
          style: QuranTokens.poppins(QuranTokens.tsLastReadTitle).copyWith(
            color: QuranTokens.inkColor(dark),
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          copy?.body ??
              'Lokasi dipakai sekali untuk mencocokkan kota Anda dengan jadwal '
                  'shalat. Anda juga bisa memilih kota sendiri.',
          style: QuranTokens.poppins(QuranTokens.tsLastReadSub)
              .copyWith(color: QuranTokens.secondaryColor(dark)),
          textAlign: TextAlign.center,
        ),
        if (state.detail != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: QuranTokens.surfaceAlt(dark),
              borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
              border: Border.all(color: QuranTokens.border(dark)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: QuranTokens.brandColor(dark)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.detail!,
                    style: QuranTokens.poppins(QuranTokens.tsLastReadSub)
                        .copyWith(color: QuranTokens.secondaryColor(dark)),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        ..._issueActions(context, copy?.action, dark),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showLokasiSelector(context, dark),
            icon: const Icon(Icons.search),
            label: const Text('Pilih Kota Manual'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: QuranTokens.brandColor(dark),
              side: BorderSide(color: QuranTokens.brandColor(dark)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(QuranTokens.radiusButton),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Minta lokasi dengan penjelasan lebih dulu.
  ///
  /// Alasan dijelaskan di dalam aplikasi sebelum dialog izin sistem muncul,
  /// supaya pengguna tahu untuk apa lokasi dipakai. Bila izin sudah dipegang,
  /// tidak ada dialog lagi.
  Future<void> _requestGps(bool dark) async {
    if (await widget.controller.hasLocationPermission()) {
      await widget.controller.detectLocation();
      return;
    }
    if (!mounted) return;

    final lanjut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.location_on_outlined),
        title: const Text('Kenapa perlu lokasi?'),
        content: const Text(
          'Lokasi dipakai sekali untuk mencocokkan kota Anda dengan jadwal '
          'shalat. Tidak dikirim ke server mana pun, dan Anda tetap bisa '
          'memilih kota sendiri.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
              _showLokasiSelector(context, dark);
            },
            child: const Text('Pilih Kota Manual'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.my_location, size: 18),
            label: const Text('Lanjutkan'),
          ),
        ],
      ),
    );

    if (lanjut ?? false) await widget.controller.detectLocation();
  }

  /// Tombol aksi sesuai jenis masalah lokasi (ikon + label, tinggi ≥48px).
  List<Widget> _issueActions(
      BuildContext context, LocationAction? action, bool dark) {
    final gps = SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _requestGps(dark),
        icon: const Icon(Icons.my_location),
        label: Text(action == LocationAction.retry
            ? 'Coba Deteksi Lagi'
            : 'Gunakan Lokasi GPS'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: QuranTokens.brandOf(context),
          foregroundColor: QuranTokens.onBrandOf(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(QuranTokens.radiusButton),
          ),
        ),
      ),
    );

    final secondary = switch (action) {
      LocationAction.openAppSettings => _secondaryButton(
          dark,
          icon: Icons.settings_outlined,
          label: 'Buka Pengaturan Aplikasi',
          onPressed: widget.controller.openAppSettings,
        ),
      LocationAction.openLocationSettings => _secondaryButton(
          dark,
          icon: Icons.location_on_outlined,
          label: 'Buka Pengaturan Lokasi',
          onPressed: widget.controller.openLocationSettings,
        ),
      _ => null,
    };

    return [gps, if (secondary != null) ...[const SizedBox(height: 12), secondary]];
  }

  Widget _secondaryButton(
    bool dark, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) =>
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: QuranTokens.brandColor(dark),
            side: BorderSide(color: QuranTokens.brandColor(dark)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(QuranTokens.radiusButton),
            ),
          ),
        ),
      );

  // ── Loaded ────────────────────────────────────────────────────────────────

  Widget _buildLoaded(
      BuildContext context, ShalatLoaded state, bool dark) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context, state, dark)),
        if (state.locationIssue != null)
          SliverToBoxAdapter(
            child: _buildLocationNotice(context, state.locationIssue!, dark),
          ),
        SliverToBoxAdapter(
            child: _buildCountdownCard(state, dark)),
        SliverToBoxAdapter(
            child: _buildTodayGrid(state, dark)),
        SliverToBoxAdapter(
            child: _buildMonthNavigation(context, state, dark)),
        SliverToBoxAdapter(
            child: _buildMonthlyCalendar(state, dark)),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(
      BuildContext context, ShalatLoaded state, bool dark) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [QuranTokens.gradientStart, QuranTokens.gradientEnd],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mosque_outlined,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Jadwal Shalat',
                  style: QuranTokens.poppins(
                    const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // Notif toggle
              IconButton(
                onPressed: widget.controller.toggleNotification,
                icon: Icon(
                  state.notifEnabled
                      ? Icons.notifications_active
                      : Icons.notifications_off_outlined,
                  color: Colors.white,
                ),
                tooltip: state.notifEnabled
                    ? 'Matikan pengingat adzan'
                    : 'Aktifkan pengingat adzan',
              ),
            ],
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _showLokasiSelector(context, dark),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    state.lokasi,
                    style: QuranTokens.poppins(
                      const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.edit, color: Colors.white, size: 14),
              ],
            ),
          ),
          if (state.isOffline) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.wifi_off, size: 13, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  'Data offline',
                  style: QuranTokens.poppins(
                    const TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ],
          if (state.notifMessage != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    state.notifMessage!,
                    style: QuranTokens.poppins(
                      const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Countdown card ────────────────────────────────────────────────────────

  Widget _buildCountdownCard(ShalatLoaded state, bool dark) {
    final next = state.nextWaktu;
    final cd = state.countdown;

    if (next == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: QuranTokens.surface(dark),
            borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
          ),
          child: Text(
            'Semua waktu shalat hari ini telah berlalu.',
            textAlign: TextAlign.center,
            style: QuranTokens.poppins(QuranTokens.tsSurahMeta)
                .copyWith(color: QuranTokens.secondaryColor(dark)),
          ),
        ),
      );
    }

    final h = cd.inHours.toString().padLeft(2, '0');
    final m = (cd.inMinutes % 60).toString().padLeft(2, '0');
    final s = (cd.inSeconds % 60).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: QuranTokens.surface(dark),
          borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
        ),
        child: Column(
          children: [
            Text(
              'Waktu Shalat Berikutnya',
              style: QuranTokens.poppins(QuranTokens.tsSurahMeta)
                  .copyWith(color: QuranTokens.secondaryColor(dark)),
            ),
            const SizedBox(height: 4),
            Text(
              '${next.nama} · ${next.waktu}',
              style: QuranTokens.poppins(
                TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: QuranTokens.brandColor(dark),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CountdownUnit(value: h, label: 'Jam', dark: dark),
                _CountdownSep(dark: dark),
                _CountdownUnit(value: m, label: 'Menit', dark: dark),
                _CountdownSep(dark: dark),
                _CountdownUnit(value: s, label: 'Detik', dark: dark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Today grid (8 waktu) ──────────────────────────────────────────────────

  Widget _buildTodayGrid(ShalatLoaded state, bool dark) {
    final today = state.today;
    if (today == null) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final entries = today.allWaktu;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Hari Ini · ${today.hari}, ${today.tanggal} ${state.jadwal.bulanNama}',
            dark: dark,
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.9,
            ),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final entry = entries[i];
              final isPast = entry.dateTime.isBefore(now);
              final isNext = state.nextWaktu?.nama == entry.nama;
              return _WaktuCard(
                entry: entry,
                isPast: isPast,
                isNext: isNext,
                dark: dark,
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Month navigation ──────────────────────────────────────────────────────

  Widget _buildMonthNavigation(
      BuildContext context, ShalatLoaded state, bool dark) {
    final jadwal = state.jadwal;
    final now = DateTime.now();
    final isCurrentMonth =
        jadwal.bulan == now.month && jadwal.tahun == now.year;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _SectionTitle(
              title: '${jadwal.bulanNama} ${jadwal.tahun}', dark: dark),
          const Spacer(),
          IconButton(
            onPressed: () {
              final prev = DateTime(jadwal.tahun, jadwal.bulan - 1);
              widget.controller.loadBulan(prev.month, prev.year);
            },
            icon:
                Icon(Icons.chevron_left, color: QuranTokens.inkColor(dark)),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: isCurrentMonth
                ? null
                : () {
                    widget.controller.loadBulan(now.month, now.year);
                  },
            icon: Icon(
              Icons.today,
              color: isCurrentMonth
                  ? QuranTokens.secondaryColor(dark)
                  : QuranTokens.brandColor(dark),
            ),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: () {
              final next = DateTime(jadwal.tahun, jadwal.bulan + 1);
              widget.controller.loadBulan(next.month, next.year);
            },
            icon:
                Icon(Icons.chevron_right, color: QuranTokens.inkColor(dark)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // ── Monthly calendar table ────────────────────────────────────────────────

  Widget _buildMonthlyCalendar(ShalatLoaded state, bool dark) {
    final now = DateTime.now();
    final isCurrentMonth =
        state.jadwal.bulan == now.month && state.jadwal.tahun == now.year;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: QuranTokens.surface(dark),
          borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
        ),
        child: Column(
          children: [
            // Header row
            _CalendarHeaderRow(dark: dark),
            const Divider(height: 1),
            // Data rows
            ...state.jadwal.jadwal.map((waktu) {
              final isToday = isCurrentMonth && waktu.tanggal == now.day;
              return _CalendarDataRow(
                waktu: waktu,
                isToday: isToday,
                dark: dark,
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Location notice ───────────────────────────────────────────────────────

  /// Catatan ramah saat deteksi GPS gagal padahal jadwal sudah tampil dari
  /// lokasi tersimpan. Tidak menghalangi apa pun — hanya informasi + aksi.
  Widget _buildLocationNotice(
      BuildContext context, LocationIssue issue, bool dark) {
    final copy = copyForIssue(issue);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: QuranTokens.surfaceAlt(dark),
        borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
        border: Border.all(color: QuranTokens.border(dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_off_outlined,
                  size: 20, color: QuranTokens.brandColor(dark)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.title,
                      style: QuranTokens.poppins(QuranTokens.tsLastReadTag)
                          .copyWith(
                        color: QuranTokens.inkColor(dark),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Jadwal di bawah memakai lokasi tersimpan '
                      '(${copy.body})',
                      style: QuranTokens.poppins(QuranTokens.tsLastReadSub)
                          .copyWith(color: QuranTokens.textMuted(dark)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _requestGps(dark),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: QuranTokens.brandColor(dark),
                  side: BorderSide(color: QuranTokens.brandColor(dark)),
                ),
              ),
              if (copy.action == LocationAction.openAppSettings)
                OutlinedButton.icon(
                  onPressed: widget.controller.openAppSettings,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Pengaturan Aplikasi'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: QuranTokens.brandColor(dark),
                    side: BorderSide(color: QuranTokens.brandColor(dark)),
                  ),
                ),
              if (copy.action == LocationAction.openLocationSettings)
                OutlinedButton.icon(
                  onPressed: widget.controller.openLocationSettings,
                  icon: const Icon(Icons.location_on_outlined, size: 18),
                  label: const Text('Pengaturan Lokasi'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: QuranTokens.brandColor(dark),
                    side: BorderSide(color: QuranTokens.brandColor(dark)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildError(BuildContext context, String message, bool dark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: QuranTokens.secondaryColor(dark)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: QuranTokens.poppins(QuranTokens.tsSurahMeta)
                  .copyWith(color: QuranTokens.secondaryColor(dark)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: widget.controller.init,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: QuranTokens.brandOf(context),
                foregroundColor: QuranTokens.onBrandOf(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Lokasi selector ───────────────────────────────────────────────────────

  void _showLokasiSelector(BuildContext context, bool dark) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: QuranTokens.background(dark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => LokasiSelectorSheet(
        controller: widget.controller,
        dark: dark,
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.dark});
  final String title;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: QuranTokens.poppins(
        TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: QuranTokens.brandColor(dark),
        ),
      ),
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  const _CountdownUnit(
      {required this.value, required this.label, required this.dark});
  final String value;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [QuranTokens.gradientStart, QuranTokens.gradientEnd],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: QuranTokens.poppins(
              const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: QuranTokens.poppins(
            TextStyle(fontSize: 11, color: QuranTokens.secondaryColor(dark)),
          ),
        ),
      ],
    );
  }
}

class _CountdownSep extends StatelessWidget {
  const _CountdownSep({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 16),
      child: Text(
        ':',
        style: QuranTokens.poppins(
          TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: QuranTokens.inkColor(dark),
          ),
        ),
      ),
    );
  }
}

class _WaktuCard extends StatelessWidget {
  const _WaktuCard({
    required this.entry,
    required this.isPast,
    required this.isNext,
    required this.dark,
  });

  final ShalatEntry entry;
  final bool isPast;
  final bool isNext;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: isNext
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [QuranTokens.gradientStart, QuranTokens.gradientEnd],
              )
            : null,
        color: isNext ? null : QuranTokens.surface(dark),
        borderRadius: BorderRadius.circular(10),
        border: isNext
            ? null
            : Border.all(
                color: QuranTokens.divider(dark),
                width: 1,
              ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            entry.nama,
            style: QuranTokens.poppins(
              TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isNext
                    ? Colors.white
                    : isPast
                        ? QuranTokens.secondaryColor(dark)
                        : QuranTokens.inkColor(dark),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.waktu,
            style: QuranTokens.poppins(
              TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isNext
                    ? Colors.white
                    : isPast
                        ? QuranTokens.secondaryColor(dark)
                        : QuranTokens.brandColor(dark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarHeaderRow extends StatelessWidget {
  const _CalendarHeaderRow({required this.dark});
  final bool dark;

  static const _headers = [
    'Tgl', 'Imsak', 'Subuh', 'Terbit',
    'Dhuha', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: _headers.map((h) {
          return Expanded(
            child: Text(
              h,
              textAlign: TextAlign.center,
              style: QuranTokens.poppins(
                TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: QuranTokens.brandColor(dark),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CalendarDataRow extends StatelessWidget {
  const _CalendarDataRow({
    required this.waktu,
    required this.isToday,
    required this.dark,
  });

  final WaktuShalat waktu;
  final bool isToday;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final values = [
      '${waktu.tanggal}',
      waktu.imsak,
      waktu.subuh,
      waktu.terbit,
      waktu.dhuha,
      waktu.dzuhur,
      waktu.ashar,
      waktu.maghrib,
      waktu.isya,
    ];

    return Container(
      color: isToday
          ? QuranTokens.brandColor(dark).withValues(alpha: 0.08)
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          children: values.asMap().entries.map((e) {
            final isDate = e.key == 0;
            return Expanded(
              child: Text(
                e.value,
                textAlign: TextAlign.center,
                style: QuranTokens.poppins(
                  TextStyle(
                    fontSize: 9,
                    fontWeight:
                        isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isDate && isToday
                        ? QuranTokens.brandColor(dark)
                        : QuranTokens.inkColor(dark)
                            .withValues(alpha: isToday ? 1.0 : 0.85),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
