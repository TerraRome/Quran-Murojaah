import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/qari.dart';

/// Persistensi pilihan qari user menggunakan SharedPreferences.
///
/// Key: `murottal_qari` — menyimpan ID qari ("01"–"06").
/// Default: Misyary Rasyid Al-Afasy ("05").
class QariStore {
  QariStore(this._prefs);

  /// Buat store sementara tanpa SharedPreferences — selalu kembalikan default qari.
  /// Dipakai saat prefs belum siap (sebelum async init selesai).
  QariStore.defaults() : _prefs = null;

  final SharedPreferences? _prefs;

  static const String _key = 'murottal_qari';

  /// Ambil qari yang sedang dipilih. Kembalikan default jika belum pernah di-set
  /// atau jika store dibuat tanpa prefs.
  Qari getSelectedQari() {
    final id = _prefs?.getString(_key);
    if (id == null) return Qari.defaultQari;
    return Qari.fromId(id);
  }

  /// Simpan pilihan qari. No-op jika store dibuat tanpa prefs.
  Future<void> setSelectedQari(Qari qari) async {
    await _prefs?.setString(_key, qari.id);
  }

  /// Reset ke qari default. No-op jika store dibuat tanpa prefs.
  Future<void> resetToDefault() async {
    await _prefs?.remove(_key);
  }

  /// Cek apakah qari yang diberikan adalah qari aktif saat ini.
  bool isSelected(Qari qari) => getSelectedQari().id == qari.id;
}
