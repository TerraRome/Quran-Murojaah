import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/jadwal_shalat_model.dart';

/// Local data source untuk cache jadwal shalat + lokasi tersimpan.
///
/// Keys:
///   shalat_cache_{provinsi}_{kabkota}_{bulan}_{tahun} → JSON JadwalShalatModel
///   shalat_last_provinsi  → string
///   shalat_last_kabkota   → string
///   shalat_notif_enabled  → bool
class ShalatLocalDataSource {
  static const _provinsiKey = 'shalat_last_provinsi';
  static const _kabkotaKey = 'shalat_last_kabkota';
  static const _notifKey = 'shalat_notif_enabled';

  String _cacheKey(String provinsi, String kabkota, int bulan, int tahun) =>
      'shalat_cache_${provinsi}_${kabkota}_${bulan}_$tahun'
          .replaceAll(' ', '_');

  // ── Cache jadwal ─────────────────────────────────────────────────────────

  Future<void> saveJadwal(JadwalShalatModel jadwal) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _cacheKey(
        jadwal.provinsi, jadwal.kabkota, jadwal.bulan, jadwal.tahun);
    await prefs.setString(key, jsonEncode(jadwal.toJson()));
  }

  Future<JadwalShalatModel?> getCachedJadwal({
    required String provinsi,
    required String kabkota,
    required int bulan,
    required int tahun,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _cacheKey(provinsi, kabkota, bulan, tahun);
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return JadwalShalatModel.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  // ── Lokasi tersimpan ──────────────────────────────────────────────────────

  Future<void> saveLokasi(String provinsi, String kabkota) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_provinsiKey, provinsi);
    await prefs.setString(_kabkotaKey, kabkota);
  }

  Future<({String? provinsi, String? kabkota})> getSavedLokasi() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      provinsi: prefs.getString(_provinsiKey),
      kabkota: prefs.getString(_kabkotaKey),
    );
  }

  Future<void> clearLokasi() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_provinsiKey);
    await prefs.remove(_kabkotaKey);
  }

  // ── Notifikasi setting ────────────────────────────────────────────────────

  Future<void> setNotifEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifKey, enabled);
  }

  Future<bool> isNotifEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifKey) ?? false;
  }
}
