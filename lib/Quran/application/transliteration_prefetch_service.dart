import '../data/datasources/equran_remote_datasource.dart';
import '../data/datasources/transliteration_local_datasource.dart';
import '../murojaah/application/arabic_matcher.dart';

/// Service yang men-prefetch transliteration (teksLatin) semua 114 surah
/// dari API equran.id saat app pertama kali boot, lalu menyimpannya ke cache
/// SharedPreferences untuk akses offline.
///
/// Alur:
/// 1. Cek `isAllFetched` — jika true, skip (sudah pernah selesai).
/// 2. Fetch surah 1–114 secara sequential (bukan parallel — jaga server).
/// 3. Setiap surah: jika sudah di-cache individual, skip; jika belum, fetch + save.
/// 4. Setelah semua berhasil, tandai `markAllFetched()`.
///
/// Dipanggil fire-and-forget dari `main.dart` — tidak blocking UI.
/// Error per surah diabaikan (surah tersebut bisa di-fetch ulang next boot).
class TransliterationPrefetchService {
  TransliterationPrefetchService({
    required EquranRemoteDataSource remote,
    required TransliterationLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  final EquranRemoteDataSource _remote;
  final TransliterationLocalDataSource _local;

  static const int _totalSurahs = 114;

  /// Mulai prefetch semua transliteration.
  ///
  /// Fire-and-forget: caller tidak perlu await. Error ditangani internal.
  Future<void> prefetchAll() async {
    // Jika sudah pernah selesai sebelumnya, skip.
    if (await _local.isAllFetched) return;

    var successCount = 0;
    for (var i = 1; i <= _totalSurahs; i++) {
      try {
        // Skip jika surah ini sudah di-cache.
        if (await _local.isCached(i)) {
          successCount++;
          continue;
        }

        final data = await _remote.getTransliterations(i);
        if (data.isEmpty) continue;

        // Pre-compute normalizedText untuk setiap ayat sebelum disimpan.
        // Ini agar normalisasi tidak perlu diulang saat runtime matching.
        final normalized = data.map(
          (verseNum, latin) => MapEntry(
            verseNum,
            latin, // raw latin tetap disimpan
          ),
        );

        await _local.save(i, normalized);
        successCount++;

        // Jeda kecil antar request agar tidak membebani server.
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (_) {
        // Abaikan error per surah — akan di-retry pada boot berikutnya.
        continue;
      }
    }

    // Tandai selesai hanya jika semua 114 surah berhasil di-cache.
    if (successCount == _totalSurahs) {
      await _local.markAllFetched();
    }
  }

  /// Muat transliteration untuk satu surah dari cache, lalu inject ke
  /// list verses. Digunakan oleh MushafRendererPage saat load surah.
  ///
  /// Mengembalikan map nomorAyat → (transliteration, normalizedText).
  Future<Map<int, ({String transliteration, String normalizedText})>>
      loadForSurah(int surahNumber) async {
    final cached = await _local.load(surahNumber);
    if (cached == null) {
      // Belum di-cache — coba fetch langsung (fallback online).
      try {
        final data = await _remote.getTransliterations(surahNumber);
        await _local.save(surahNumber, data);
        return _buildResult(data);
      } catch (_) {
        return {};
      }
    }
    return _buildResult(cached);
  }

  Map<int, ({String transliteration, String normalizedText})> _buildResult(
      Map<int, String> raw) {
    return raw.map(
      (verseNum, latin) => MapEntry(
        verseNum,
        (
          transliteration: latin,
          normalizedText: ArabicMatcher.normalizeLatin(latin),
        ),
      ),
    );
  }
}
