import 'package:dio/dio.dart';

import '../models/jadwal_shalat_model.dart';

/// Remote data source untuk API equran.id/api/v2/shalat.
///
/// Base URL: https://equran.id/api/v2
/// - GET /shalat/provinsi → List<String> provinsi
/// - POST /shalat/kabkota → List<String> kabkota (body: {"provinsi": "..."})
/// - POST /shalat → JadwalShalatModel (body: {"provinsi": "...", "kabkota": "...", "bulan": 1, "tahun": 2026})
abstract class ShalatRemoteDataSource {
  Future<List<String>> getProvinsi();
  Future<List<String>> getKabkota(String provinsi);
  Future<JadwalShalatModel> getJadwalShalat({
    required String provinsi,
    required String kabkota,
    int? bulan,
    int? tahun,
  });
}

class ShalatRemoteDataSourceImpl implements ShalatRemoteDataSource {
  ShalatRemoteDataSourceImpl({Dio? dio}) : _dio = dio ?? _buildDio();

  final Dio _dio;

  static const String _baseUrl = 'https://equran.id/api/v2';

  static Dio _buildDio() => Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Accept': 'application/json'},
        ),
      );

  @override
  Future<List<String>> getProvinsi() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/shalat/provinsi');
      if (response.data == null) {
        throw const ShalatApiException('Response kosong untuk provinsi');
      }
      final data = response.data!['data'];
      if (data is! List) {
        throw const ShalatApiException('Format response provinsi tidak valid');
      }
      return data.map((e) => e.toString()).toList();
    } on DioException catch (e) {
      throw ShalatApiException(_mapDioError(e));
    }
  }

  @override
  Future<List<String>> getKabkota(String provinsi) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/shalat/kabkota',
        data: {'provinsi': provinsi},
      );
      if (response.data == null) {
        throw ShalatApiException('Response kosong untuk kabkota $provinsi');
      }
      final data = response.data!['data'];
      if (data is! List) {
        throw const ShalatApiException('Format response kabkota tidak valid');
      }
      return data.map((e) => e.toString()).toList();
    } on DioException catch (e) {
      throw ShalatApiException(_mapDioError(e));
    }
  }

  @override
  Future<JadwalShalatModel> getJadwalShalat({
    required String provinsi,
    required String kabkota,
    int? bulan,
    int? tahun,
  }) async {
    try {
      final now = DateTime.now();
      final body = <String, dynamic>{
        'provinsi': provinsi,
        'kabkota': kabkota,
        if (bulan != null) 'bulan': bulan else 'bulan': now.month,
        if (tahun != null) 'tahun': tahun else 'tahun': now.year,
      };

      final response = await _dio.post<Map<String, dynamic>>(
        '/shalat',
        data: body,
      );

      if (response.data == null) {
        throw ShalatApiException(
          'Response kosong untuk jadwal shalat $kabkota',
        );
      }

      final dataMap = response.data!['data'];
      if (dataMap is! Map<String, dynamic>) {
        throw const ShalatApiException('Format response jadwal tidak valid');
      }

      return JadwalShalatModel.fromJson(dataMap);
    } on DioException catch (e) {
      throw ShalatApiException(_mapDioError(e));
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

/// Exception khusus untuk error dari API jadwal shalat.
class ShalatApiException implements Exception {
  const ShalatApiException(this.message);
  final String message;

  @override
  String toString() => 'ShalatApiException: $message';
}
