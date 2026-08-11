import '../data/datasources/equran_remote_datasource.dart';
import '../data/datasources/quran_asset_datasource.dart';
import '../data/datasources/transliteration_local_datasource.dart';
import '../data/last_read_store.dart';
import '../data/repositories/quran_repository_impl.dart';
import '../domain/repositories/quran_repository.dart';
import '../doa/application/doa_controller.dart';
import '../doa/data/datasources/doa_local_datasource.dart';
import '../doa/data/datasources/doa_remote_datasource.dart';
import '../shalat/application/location_service.dart';
import '../shalat/application/shalat_controller.dart';
import '../shalat/data/datasources/shalat_local_datasource.dart';
import '../shalat/data/datasources/shalat_remote_datasource.dart';
import 'quran_controller.dart';
import 'transliteration_prefetch_service.dart';

/// Dependensi module Quran — dibangun sekali dan dibagikan antar halaman.
///
/// Module ini zero-dependency terhadap DI global (get_it) supaya tetap
/// self-contained; konstruktor disuntikkan eksplisit dari router.
class QuranDependencies {
  QuranDependencies._();

  static final QuranRepository _repository =
      QuranRepositoryImpl(QuranAssetDataSource());

  static const LastReadStore _lastReadStore = LastReadStore();

  static final QuranController controller =
      QuranController(_repository, _lastReadStore);

  static final DoaController doaController = DoaController(
    remote: DoaRemoteDataSourceImpl(),
    local: DoaLocalDataSource(),
  );

  static final ShalatController shalatController = ShalatController(
    remote: ShalatRemoteDataSourceImpl(),
    local: ShalatLocalDataSource(),
    locationService: LocationService(),
  );

  static final TransliterationPrefetchService transliterationService =
      TransliterationPrefetchService(
    remote: EquranRemoteDataSourceImpl(),
    local: TransliterationLocalDataSource(),
  );
}
