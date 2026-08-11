import 'package:alice/alice.dart';
import 'package:alice_dio/alice_dio_adapter.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../models/surah_audio_model.dart';
import '../models/surah_latin_model.dart';
import '../models/tafsir_response_model.dart';

/// Abstraksi remote data source untuk API equran.id v2.
abstract class EquranRemoteDataSource {
  Future<SurahAudioModel> getSurahAudio(int surahNumber);
  Future<TafsirResponseModel> getTafsir(int surahNumber);

  /// Fetch transliteration (teksLatin) per ayat untuk satu surah.
  /// Mengembalikan map nomorAyat → teksLatin.
  Future<Map<int, String>> getTransliterations(int surahNumber);
}

/// Implementasi HTTP client untuk API equran.id v2.
///
/// Base URL: https://equran.id/api/v2
/// - GET /surat/{nomor}  → detail surah + audio per ayat + teksLatin + audio full
/// - GET /tafsir/{nomor} → tafsir lengkap per ayat
class EquranRemoteDataSourceImpl implements EquranRemoteDataSource {
  EquranRemoteDataSourceImpl({Dio? dio}) : _dio = dio ?? _buildDio();

  final Dio _dio;

  static const String _baseUrl = 'https://equran.id/api/v2';

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
      ),
    );
    // Inject Alice HTTP inspector bila tersedia (debug/dev build).
    if (GetIt.I.isRegistered<Alice>()) {
      final alice = GetIt.I<Alice>();
      final adapter = AliceDioAdapter();
      alice.addAdapter(adapter);
      dio.interceptors.add(adapter);
    }
    return dio;
  }

  @override
  Future<SurahAudioModel> getSurahAudio(int surahNumber) async {
    assert(surahNumber >= 1 && surahNumber <= 114, 'surahNumber harus 1–114');
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/surat/$surahNumber',
      );
      if (response.data == null) {
        throw EquranApiException('Response kosong untuk surah $surahNumber');
      }
      return SurahAudioModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw EquranApiException(_mapDioError(e));
    }
  }

  @override
  Future<TafsirResponseModel> getTafsir(int surahNumber) async {
    assert(surahNumber >= 1 && surahNumber <= 114, 'surahNumber harus 1–114');
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/tafsir/$surahNumber',
      );
      if (response.data == null) {
        throw EquranApiException('Response kosong untuk tafsir $surahNumber');
      }
      return TafsirResponseModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw EquranApiException(_mapDioError(e));
    }
  }

  @override
  Future<Map<int, String>> getTransliterations(int surahNumber) async {
    assert(surahNumber >= 1 && surahNumber <= 114, 'surahNumber harus 1–114');
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/surat/$surahNumber',
      );
      if (response.data == null) {
        throw EquranApiException(
            'Response kosong untuk transliteration surah $surahNumber');
      }
      final model = SurahLatinModel.fromJson(response.data!);
      return model.verses;
    } on DioException catch (e) {
      throw EquranApiException(_mapDioError(e));
    }
  }

  String _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Koneksi timeout. Periksa koneksi internet Anda.';
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        return 'Server mengembalikan error $status.';
      default:
        return 'Terjadi kesalahan jaringan: ${e.message}';
    }
  }
}

/// Exception khusus untuk error dari API equran.id.
class EquranApiException implements Exception {
  const EquranApiException(this.message);
  final String message;

  @override
  String toString() => 'EquranApiException: $message';
}
