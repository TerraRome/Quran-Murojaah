import 'package:fpdart/fpdart.dart';

import '../entities/surah.dart';
import '../failures/quran_failure.dart';

/// Kontrak akses data Al-Quran.
///
/// Implementasi bisa berupa data source aset lokal, API online, atau cache —
/// UI tidak perlu tahu sumbernya. Mengikuti Repository Pattern (Second Brain 08).
abstract interface class QuranRepository {
  /// Memuat seluruh daftar surah (termasuk ayat-ayatnya).
  Future<Either<QuranFailure, List<Surah>>> getSurahs();

  /// Mengambil satu surah berdasarkan nomor (1..114).
  Future<Either<QuranFailure, Surah>> getSurah(int number);
}
