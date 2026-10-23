import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../application/compass_provider.dart';
import '../../domain/qibla.dart';

/// Kartu arah kiblat.
///
/// Bukan hanya jarum: derajat kiblat, petunjuk putar, tanda "sudah menghadap",
/// dan petunjuk kalibrasi selalu berupa teks juga. Perangkat tanpa kompas tetap
/// mendapat derajat kiblat + pesan ramah.
class KiblatCard extends StatefulWidget {
  const KiblatCard({
    super.key,
    required this.koordinat,
    required this.dark,
    this.compass = const PluginCompassProvider(),
    this.onDetectLocation,
    this.onRetry,
  });

  /// Null = arah kiblat belum bisa dihitung.
  final ({double latitude, double longitude})? koordinat;
  final bool dark;
  final CompassProvider compass;
  final VoidCallback? onDetectLocation;

  /// Cari ulang koordinat kota tersimpan (mis. geocoding gagal saat offline).
  final VoidCallback? onRetry;

  @override
  State<KiblatCard> createState() => _KiblatCardState();
}

class _KiblatCardState extends State<KiblatCard> {
  /// Batas waktu menunggu pembacaan pertama sebelum dianggap tanpa kompas.
  static const _sensorTimeout = Duration(seconds: 3);

  StreamSubscription<CompassReading>? _sub;
  Timer? _timeout;
  double? _heading;
  double? _accuracy;
  bool _noCompass = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(KiblatCard old) {
    super.didUpdateWidget(old);
    if (old.koordinat != widget.koordinat || old.compass != widget.compass) {
      _listen();
    }
  }

  void _listen() {
    _sub?.cancel();
    _timeout?.cancel();
    _heading = null;
    _accuracy = null;
    _noCompass = false;
    if (widget.koordinat == null) return;

    _timeout = Timer(_sensorTimeout, () {
      if (!mounted || _heading != null) return;
      setState(() => _noCompass = true);
    });

    _sub = widget.compass.readings().listen(
      (reading) {
        if (!mounted) return;
        _timeout?.cancel();
        setState(() {
          _heading = reading.heading;
          _accuracy = reading.accuracy;
          _noCompass = reading.heading == null;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _noCompass = true);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final koordinat = widget.koordinat;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QuranTokens.surface(dark),
        borderRadius: BorderRadius.circular(QuranTokens.radiusCard),
        border: Border.all(color: QuranTokens.border(dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.explore_outlined,
                size: 20,
                color: QuranTokens.brandColor(dark),
              ),
              const SizedBox(width: 8),
              Text(
                'Arah Kiblat',
                style: QuranTokens.poppins(QuranTokens.tsLastReadTag).copyWith(
                  color: QuranTokens.inkColor(dark),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (koordinat == null)
            _buildNeedLocation(dark)
          else
            _buildCompass(
              dark,
              qiblaBearing(koordinat.latitude, koordinat.longitude),
            ),
        ],
      ),
    );
  }

  Widget _buildNeedLocation(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Arah kiblat butuh lokasi Anda. Deteksi lewat GPS, atau coba cari '
          'ulang koordinat kota yang sudah dipilih. Setelah lokasi diketahui, '
          'arah kiblat tetap tersedia tanpa internet.',
          style: QuranTokens.poppins(
            QuranTokens.tsLastReadSub,
          ).copyWith(color: QuranTokens.textMuted(dark), fontSize: 14),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba lagi'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: QuranTokens.brandColor(dark),
                side: BorderSide(color: QuranTokens.brandColor(dark)),
              ),
            ),
            FilledButton.icon(
              onPressed: widget.onDetectLocation,
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Gunakan lokasi GPS'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompass(bool dark, double bearing) {
    final heading = _heading;
    final muted = QuranTokens.textMuted(dark);
    final facing = heading != null && isFacingQibla(heading, bearing);
    final instruction = heading == null
        ? 'Arahkan perangkat ${bearing.round()} derajat dari utara.'
        : qiblaInstruction(heading, bearing);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kiblat ${bearing.round()}° dari utara',
          style: QuranTokens.poppins(QuranTokens.tsLastReadTag).copyWith(
            color: QuranTokens.inkColor(dark),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Letakkan ponsel mendatar, lalu putar badan Anda sampai penanda '
          'menghadap kiblat.',
          style: QuranTokens.poppins(
            QuranTokens.tsLastReadSub,
          ).copyWith(color: QuranTokens.textMuted(dark), fontSize: 14),
        ),
        const SizedBox(height: 12),
        Center(
          child: Semantics(
            label: 'Kompas kiblat. $instruction',
            child: _Dial(
              dark: dark,
              bearing: bearing,
              heading: heading,
              facing: facing,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              facing
                  ? Icons.check_circle
                  : (heading == null ? Icons.info_outline : Icons.rotate_right),
              size: 20,
              color: facing
                  ? QuranTokens.correct(dark)
                  : QuranTokens.brandColor(dark),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                instruction,
                style: QuranTokens.poppins(QuranTokens.tsLastReadSub).copyWith(
                  color: facing
                      ? QuranTokens.correct(dark)
                      : QuranTokens.inkColor(dark),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (_noCompass) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sensors_off, size: 18, color: muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Perangkat ini tidak punya kompas. Pakai angka derajat di atas '
                  'dengan kompas biasa.',
                  style: QuranTokens.poppins(
                    QuranTokens.tsLastReadSub,
                  ).copyWith(color: muted, fontSize: 14),
                ),
              ),
            ],
          ),
        ] else if (!facing && (_accuracy == null || _accuracy! > 15)) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.screen_rotation_outlined, size: 18, color: muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kompas kurang akurat. Gerakkan perangkat membentuk angka 8 '
                  'untuk kalibrasi.',
                  style: QuranTokens.poppins(
                    QuranTokens.tsLastReadSub,
                  ).copyWith(color: muted, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Cincin kompas + jarum. Jarum menunjuk kiblat relatif terhadap utara
/// perangkat.
class _Dial extends StatelessWidget {
  const _Dial({
    required this.dark,
    required this.bearing,
    required this.heading,
    required this.facing,
  });

  final bool dark;
  final double bearing;
  final double? heading;
  final bool facing;

  @override
  Widget build(BuildContext context) {
    final accent = facing
        ? QuranTokens.correct(dark)
        : QuranTokens.brandColor(dark);
    // Tanpa kompas, cincin dianggap menghadap utara: jarum = bearing.
    final needleDegrees = heading == null
        ? bearing
        : shortestTurn(heading!, bearing);

    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: QuranTokens.surfaceAlt(dark),
              border: Border.all(color: QuranTokens.border(dark), width: 2),
            ),
          ),
          Positioned(
            top: 6,
            child: Text(
              'U',
              style: QuranTokens.poppins(
                TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: QuranTokens.textMuted(dark),
                ),
              ),
            ),
          ),
          Transform.rotate(
            angle: needleDegrees * math.pi / 180,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.navigation, size: 44, color: accent),
                const SizedBox(height: 2),
                Container(width: 2, height: 34, color: accent),
              ],
            ),
          ),
          Positioned(
            bottom: 6,
            child: Icon(Icons.mosque_outlined, size: 16, color: accent),
          ),
        ],
      ),
    );
  }
}
