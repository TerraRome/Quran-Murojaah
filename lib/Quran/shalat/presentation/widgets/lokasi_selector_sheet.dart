import 'package:flutter/material.dart';

import '../../../data/quran_tokens.dart';
import '../../application/shalat_controller.dart';

/// Bottom sheet untuk pilih provinsi + kabkota secara manual.
class LokasiSelectorSheet extends StatefulWidget {
  const LokasiSelectorSheet({
    super.key,
    required this.controller,
    required this.dark,
  });

  final ShalatController controller;
  final bool dark;

  @override
  State<LokasiSelectorSheet> createState() => _LokasiSelectorSheetState();
}

class _LokasiSelectorSheetState extends State<LokasiSelectorSheet> {
  List<String>? _provinsiList;
  List<String>? _kabkotaList;
  String? _selectedProvinsi;
  String? _selectedKabkota;
  bool _loadingProvinsi = true;
  bool _loadingKabkota = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProvinsi();
  }

  Future<void> _loadProvinsi() async {
    setState(() {
      _loadingProvinsi = true;
      _error = null;
    });
    try {
      final list = await widget.controller.getProvinsi();
      if (mounted) {
        setState(() {
          _provinsiList = list;
          _loadingProvinsi = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Daftar provinsi belum bisa dimuat. Periksa koneksi internet Anda.';
          _loadingProvinsi = false;
        });
      }
    }
  }

  Future<void> _onProvinsiChanged(String? provinsi) async {
    if (provinsi == null) return;
    setState(() {
      _selectedProvinsi = provinsi;
      _selectedKabkota = null;
      _kabkotaList = null;
      _loadingKabkota = true;
      _error = null;
    });
    try {
      final list = await widget.controller.getKabkota(provinsi);
      if (mounted) {
        setState(() {
          _kabkotaList = list;
          _loadingKabkota = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Daftar kota belum bisa dimuat. Periksa koneksi internet Anda.';
          _loadingKabkota = false;
        });
      }
    }
  }

  Future<void> _onConfirm() async {
    if (_selectedProvinsi == null || _selectedKabkota == null) return;
    Navigator.of(context).pop();
    await widget.controller.setLokasi(_selectedProvinsi!, _selectedKabkota!);
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: QuranTokens.background(dark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: QuranTokens.divider(dark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Pilih Lokasi',
                      style: QuranTokens.poppins(QuranTokens.tsLastReadTitle)
                          .copyWith(
                            color: QuranTokens.inkColor(dark),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: QuranTokens.secondaryColor(dark),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Error
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: QuranTokens.wrongOf(
                            context,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: QuranTokens.poppins(
                            TextStyle(
                              fontSize: 13,
                              color: QuranTokens.wrongOf(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Provinsi dropdown
                    Text(
                      'Provinsi',
                      style: QuranTokens.poppins(
                        TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: QuranTokens.brandColor(dark),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _loadingProvinsi
                        ? const Center(child: CircularProgressIndicator())
                        : _buildDropdown(
                            items: _provinsiList ?? [],
                            value: _selectedProvinsi,
                            hint: 'Pilih provinsi...',
                            onChanged: _onProvinsiChanged,
                            dark: dark,
                          ),

                    const SizedBox(height: 20),

                    // Kabkota dropdown
                    Text(
                      'Kabupaten / Kota',
                      style: QuranTokens.poppins(
                        TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: QuranTokens.brandColor(dark),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _loadingKabkota
                        ? const Center(child: CircularProgressIndicator())
                        : _selectedProvinsi == null
                        ? Text(
                            'Pilih provinsi terlebih dahulu',
                            style: QuranTokens.poppins(
                              TextStyle(
                                fontSize: 13,
                                color: QuranTokens.secondaryColor(dark),
                              ),
                            ),
                          )
                        : _buildDropdown(
                            items: _kabkotaList ?? [],
                            value: _selectedKabkota,
                            hint: 'Pilih kabupaten/kota...',
                            onChanged: (val) =>
                                setState(() => _selectedKabkota = val),
                            dark: dark,
                          ),

                    const SizedBox(height: 28),

                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            (_selectedProvinsi != null &&
                                _selectedKabkota != null)
                            ? _onConfirm
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: QuranTokens.brandOf(context),
                          foregroundColor: QuranTokens.onBrandOf(context),
                          disabledBackgroundColor: QuranTokens.brandOf(
                            context,
                          ).withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Gunakan Lokasi Ini',
                          style: QuranTokens.poppins(
                            const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDropdown({
    required List<String> items,
    required String? value,
    required String hint,
    required ValueChanged<String?> onChanged,
    required bool dark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: QuranTokens.surface(dark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: QuranTokens.divider(dark)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: QuranTokens.poppins(
              TextStyle(fontSize: 14, color: QuranTokens.secondaryColor(dark)),
            ),
          ),
          isExpanded: true,
          dropdownColor: QuranTokens.surface(dark),
          style: QuranTokens.poppins(
            TextStyle(fontSize: 14, color: QuranTokens.inkColor(dark)),
          ),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
