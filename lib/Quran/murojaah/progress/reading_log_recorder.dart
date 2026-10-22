import 'package:flutter/widgets.dart';

import 'activity_entry.dart';
import 'progress_controller.dart';

/// Mencatat item yang benar-benar dibaca (ayat, tafsir, doa) ke log aktivitas.
///
/// Aturan kredit:
/// - item dianggap terbaca setelah tampil [dwell] (default 5 detik), atau
/// - pengguna menekan "Tandai sudah dibaca".
///
/// Kredit dikumpulkan di memori dan baru ditulis saat [flush] — dipanggil ketika
/// halaman/sheet ditutup atau aplikasi masuk background. Tidak ada penulisan
/// per ayat.
///
/// Dwell dihitung dari jam ([clock]), bukan `Timer`, supaya bisa diuji tanpa
/// menunggu waktu nyata.
class ReadingLogRecorder extends ChangeNotifier {
  ReadingLogRecorder({
    required this.progress,
    required this.type,
    this.dwell = defaultDwell,
    DateTime Function()? clock,
    this.onFlushed,
  }) : _clock = clock ?? DateTime.now;

  /// Ambang "sudah dibaca" — satu konstanta untuk baca Quran, tafsir, dan doa.
  static const defaultDwell = Duration(seconds: 5);

  final MurojaahProgressController? progress;
  final ActivityType type;
  final Duration dwell;

  /// Dipanggil setelah flush selesai (mis. untuk memicu rebuild ringkasan).
  final VoidCallback? onFlushed;

  final DateTime Function() _clock;

  final Map<String, _Open> _open = {};
  final Map<String, _Open> _pending = {};
  bool _paused = false;

  /// Key yang sedang tampil — untuk test dan tombol "Tandai sudah dibaca".
  Set<String> get visibleKeys => Set.unmodifiable(_open.keys);

  /// Item yang sudah dapat kredit tetapi belum ditulis.
  int get pendingCount => _pending.length;

  bool get isPaused => _paused;

  /// Apakah item [key] sudah dapat kredit di sesi ini.
  bool isCredited(String key) => _pending.containsKey(key);

  void enter(
    String key, {
    int surahNumber = ActivityEntry.noSurah,
    int verse = 1,
    String? refId,
  }) {
    if (_paused || _open.containsKey(key) || _pending.containsKey(key)) return;
    _open[key] = _Open(
      since: _clock(),
      surahNumber: surahNumber,
      verse: verse,
      refId: refId,
    );
  }

  /// Item keluar dari layar: beri kredit bila sudah cukup lama.
  void leave(String key) {
    final item = _open.remove(key);
    if (item == null || _paused) return;
    if (_clock().difference(item.since) >= dwell) _credit(key, item);
  }

  /// Tombol "Tandai sudah dibaca": kredit semua item yang sedang tampil.
  void markVisibleAsRead() {
    for (final entry in [..._open.entries]) {
      _credit(entry.key, entry.value);
    }
  }

  void handleLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      resume();
    } else {
      pause();
    }
  }

  /// Item yang belum mencapai ambang dibuang tanpa kredit; yang sudah lewat
  /// ambang dikreditkan lalu ditulis. Dwell berhenti berjalan.
  void pause() {
    if (_paused) return;
    _paused = true;
    _creditElapsed();
    _open.clear();
    flush();
  }

  /// Mulai ulang hitungan untuk item yang masih tampil (widget mendengarkan
  /// [notifyListeners] lalu memanggil [enter] lagi).
  void resume() {
    if (!_paused) return;
    _paused = false;
    notifyListeners();
  }

  /// Tulis semua kredit yang tertunda. Ayat berurutan pada surah yang sama
  /// digabung jadi satu rentang.
  Future<void> flush() async {
    _creditElapsed();
    if (_pending.isEmpty) return;
    final items = [..._pending.values];
    _pending.clear();

    final target = progress;
    if (target == null) return;

    final bySurah = <int, List<int>>{};
    final doas = <String>{};
    for (final item in items) {
      if (type == ActivityType.doa) {
        doas.add(item.refId ?? '${item.verse}');
      } else {
        bySurah.putIfAbsent(item.surahNumber, () => []).add(item.verse);
      }
    }

    final at = _clock();
    for (final entry in bySurah.entries) {
      await target.recordVerses(
        type: type,
        surahNumber: entry.key,
        verses: entry.value,
        at: at,
      );
    }
    for (final refId in doas) {
      await target.recordDoa(refId: refId, at: at);
    }
    onFlushed?.call();
  }

  void _creditElapsed() {
    final now = _clock();
    for (final entry in [..._open.entries]) {
      if (now.difference(entry.value.since) >= dwell) {
        _credit(entry.key, entry.value);
      }
    }
  }

  void _credit(String key, _Open item) {
    _open.remove(key);
    _pending[key] = item;
  }
}

class _Open {
  const _Open({
    required this.since,
    required this.surahNumber,
    required this.verse,
    required this.refId,
  });

  final DateTime since;
  final int surahNumber;
  final int verse;
  final String? refId;
}
