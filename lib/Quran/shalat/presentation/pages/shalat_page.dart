import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../../presentation/widgets/quran_status_bar.dart';
import '../../../presentation/widgets/quran_theme_scope.dart';
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
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on_outlined,
              size: 64, color: QuranTokens.brandColor(dark)),
          const SizedBox(height: 16),
          Text(
            'Izinkan Akses Lokasi',
            style: QuranTokens.poppins(QuranTokens.tsLastReadTitle).copyWith(
              color: QuranTokens.inkColor(dark),
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Untuk menampilkan jadwal shalat yang akurat sesuai wilayahmu.',
            style: QuranTokens.poppins(QuranTokens.tsSurahMeta)
                .copyWith(color: QuranTokens.secondaryColor(dark)),
            textAlign: TextAlign.center,
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                state.errorMessage!,
                style: QuranTokens.poppins(
                  const TextStyle(fontSize: 13, color: Colors.orange),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.controller.detectLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Gunakan Lokasi GPS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: QuranTokens.brandOf(context),
                foregroundColor: QuranTokens.onBrandOf(context),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLokasiSelector(context, dark),
              icon: const Icon(Icons.search),
              label: const Text('Pilih Lokasi Manual'),
              style: OutlinedButton.styleFrom(
                foregroundColor: QuranTokens.brandColor(dark),
                side: BorderSide(color: QuranTokens.brandColor(dark)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Loaded ────────────────────────────────────────────────────────────────

  Widget _buildLoaded(
      BuildContext context, ShalatLoaded state, bool dark) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context, state, dark)),
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
