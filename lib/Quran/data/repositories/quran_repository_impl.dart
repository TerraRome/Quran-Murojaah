import 'package:fpdart/fpdart.dart';

import '../../domain/entities/surah.dart';
import '../../domain/failures/quran_failure.dart';
import '../../domain/repositories/quran_repository.dart';
import '../datasources/quran_asset_datasource.dart';

/// Implementasi [QuranRepository] berbasis aset lokal.
class QuranRepositoryImpl implements QuranRepository {
  const QuranRepositoryImpl(this._dataSource);

  final QuranAssetDataSource _dataSource;

  @override
  Future<Either<QuranFailure, List<Surah>>> getSurahs() async {
    final surahs = await _dataSource.loadSurahs();
    if (surahs == null) {
      return const Left(QuranParseFailure('Gagal memuat data Al-Quran'));
    }
    return Right(surahs);
  }

  @override
  Future<Either<QuranFailure, Surah>> getSurah(int number) async {
    final surahs = await _dataSource.loadSurahs();
    if (surahs == null) {
      return const Left(QuranParseFailure('Gagal memuat data Al-Quran'));
    }
    final surah = surahs.where((item) => item.number == number).firstOrNull;
    if (surah == null) {
      return Left(QuranAssetLoadFailure('Surah $number tidak ditemukan'));
    }
    return Right(surah);
  }
}
