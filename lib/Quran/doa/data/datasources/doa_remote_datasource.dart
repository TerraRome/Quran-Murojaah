import 'package:dio/dio.dart';

import '../../../data/network/dio_error_message.dart';
import '../models/doa_model.dart';

/// Remote data source untuk API equran.id/api/doa.
///
/// Base URL berbeda dari v2: https://equran.id (bukan /api/v2).
/// - GET /api/doa        → list semua doa (228 doa)
/// - GET /api/doa/{id}   → detail satu doa
abstract class DoaRemoteDataSource {
  Future<List<DoaModel>> getDoas();
  Future<DoaModel> getDoaDetail(int id);
}

class DoaRemoteDataSourceImpl implements DoaRemoteDataSource {
  DoaRemoteDataSourceImpl({Dio? dio}) : _dio = dio ?? _buildDio();

  final Dio _dio;

  static const String _baseUrl = 'https://equran.id';

  static Dio _buildDio() => Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Accept': 'application/json'},
        ),
      );

  @override
  Future<List<DoaModel>> getDoas() async {
    try {
      final response = await _dio.get<dynamic>('/api/doa');
      final data = response.data;

      // API mengembalikan list langsung atau wrapped dalam object
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List;
      } else {
        throw const DoaApiException('Format response tidak dikenali');
      }

      return list
          .map((e) => DoaModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw DoaApiException(dioErrorMessage(e));
    }
  }

  @override
  Future<DoaModel> getDoaDetail(int id) async {
    try {
      final response = await _dio.get<dynamic>('/api/doa/$id');
      final data = response.data;

      Map<String, dynamic> json;
      if (data is Map<String, dynamic>) {
        // bisa wrapped dalam 'data' key
        json = (data['data'] is Map<String, dynamic>)
            ? data['data'] as Map<String, dynamic>
            : data;
      } else {
        throw DoaApiException('Response kosong untuk doa $id');
      }

      return DoaModel.fromJson(json);
    } on DioException catch (e) {
      throw DoaApiException(dioErrorMessage(e));
    }
  }
}

/// Exception khusus untuk error dari API doa.
class DoaApiException implements Exception {
  const DoaApiException(this.message);
  final String message;

  @override
  String toString() => 'DoaApiException: $message';
}
