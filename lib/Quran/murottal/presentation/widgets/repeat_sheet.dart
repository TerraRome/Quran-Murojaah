import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../../presentation/widgets/quran_theme_scope.dart';
import '../../application/murottal_controller.dart';
import '../../application/repeat_sequencer.dart';

/// Bottom sheet pengaturan ulang: mode, jumlah, rentang ayat, jeda (BL-02..BL-04).
Future<void> showRepeatSheet(
  BuildContext context, {
  required MurottalController controller,
  required int totalAyat,
  required int currentAyat,
}) {
  final dark = QuranThemeScope.darkOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: QuranTokens.surface(dark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _RepeatSheet(
      controller: controller,
      totalAyat: totalAyat,
      currentAyat: currentAyat,
      dark: dark,
    ),
  );
}

class _RepeatSheet extends StatelessWidget {
  const _RepeatSheet({
    required this.controller,
    required this.totalAyat,
    required this.currentAyat,
    required this.dark,
  });

  final MurottalController controller;
  final int totalAyat;
  final int currentAyat;
  final bool dark;

  void _setMode(RepeatSettings s, RepeatKind mode) {
    if (mode == RepeatKind.range) {
      final start = currentAyat.clamp(1, totalAyat);
      controller.setRepeat(s.copyWith(
        mode: mode,
        rangeStart: start,
        rangeEnd: (start + 2).clamp(1, totalAyat),
      ));
    } else {
      controller.setRepeat(s.copyWith(mode: mode));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: ValueListenableBuilder<RepeatSettings>(
          valueListenable: controller.repeat,
          builder: (context, s, _) {
            final on = s.mode != RepeatKind.off;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _title('Ulang'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _choice('Mati', 'Ulang mati', s.mode == RepeatKind.off,
                      () => _setMode(s, RepeatKind.off)),
                  _choice('Satu ayat', 'Ulang satu ayat',
                      s.mode == RepeatKind.ayat,
                      () => _setMode(s, RepeatKind.ayat)),
                  _choice('Rentang ayat', 'Ulang rentang ayat',
                      s.mode == RepeatKind.range,
                      () => _setMode(s, RepeatKind.range)),
                ]),
                if (s.mode == RepeatKind.range) ...[
                  _title('Rentang ayat'),
                  Row(children: [
                    Expanded(
                      child: _picker('Ayat awal', s.rangeStart, (v) {
                        controller.setRepeat(s.copyWith(
                          rangeStart: v,
                          rangeEnd: v > s.rangeEnd ? v : s.rangeEnd,
                        ));
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _picker('Ayat akhir', s.rangeEnd, (v) {
                        controller.setRepeat(s.copyWith(
                          rangeEnd: v,
                          rangeStart: v < s.rangeStart ? v : s.rangeStart,
                        ));
                      }),
                    ),
                  ]),
                ],
                if (on) ...[
                  _title('Jumlah ulangan'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final c in RepeatSettings.counts)
                      _choice(
                        c == RepeatSettings.infinite ? '∞' : '$c×',
                        c == RepeatSettings.infinite
                            ? 'Ulang terus-menerus'
                            : 'Ulang $c kali',
                        s.count == c,
                        () => controller.setRepeat(s.copyWith(count: c)),
                      ),
                  ]),
                  _title('Jeda antar ulangan'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final g in RepeatSettings.gaps)
                      _choice(
                        '$g dtk',
                        g == 0 ? 'Tanpa jeda' : 'Jeda $g detik',
                        s.gapSeconds == g,
                        () => controller.setRepeat(s.copyWith(gapSeconds: g)),
                      ),
                  ]),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          text,
          style: QuranTokens.poppins(
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ).copyWith(color: QuranTokens.inkColor(dark)),
        ),
      );

  Widget _choice(
      String label, String semantics, bool selected, VoidCallback onTap) {
    final brand = QuranTokens.brandColor(dark);
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: semantics,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? brand : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: selected ? brand : QuranTokens.listDivider(dark)),
          ),
          child: Text(
            label,
            style: QuranTokens.poppins(
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ).copyWith(color: selected ? Colors.white : QuranTokens.inkColor(dark)),
          ),
        ),
      ),
    );
  }

  Widget _picker(String label, int value, ValueChanged<int> onChanged) {
    return Semantics(
      label: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: QuranTokens.listDivider(dark)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            isExpanded: true,
            value: value.clamp(1, totalAyat),
            dropdownColor: QuranTokens.surface(dark),
            items: [
              for (var i = 1; i <= totalAyat; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    '$label $i',
                    style: QuranTokens.poppins(const TextStyle(fontSize: 14))
                        .copyWith(color: QuranTokens.inkColor(dark)),
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}
