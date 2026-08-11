/// Failure untuk module Quran.
sealed class QuranFailure {
  const QuranFailure(this.message);

  final String message;
}

/// Gagal memuat aset JSON Al-Quran dari bundle.
final class QuranAssetLoadFailure extends QuranFailure {
  const QuranAssetLoadFailure(super.message);
}

/// Gagal mem-parse aset JSON Al-Quran.
final class QuranParseFailure extends QuranFailure {
  const QuranParseFailure(super.message);
}
