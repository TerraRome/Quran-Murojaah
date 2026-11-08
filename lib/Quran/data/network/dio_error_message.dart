import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Terjemahan [DioException] menjadi pesan ramah untuk pengguna.
///
/// Dipakai bersama oleh data source Quran, doa, dan shalat supaya pesan yang
/// dilihat pengguna selalu sama untuk jenis kesalahan yang sama.
String dioErrorMessage(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Koneksi timeout. Periksa koneksi internet Anda.';
    case DioExceptionType.connectionError:
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
    case DioExceptionType.badResponse:
      debugPrint('[Dio] respons ${e.response?.statusCode}: ${e.message}');
      return 'Server sedang bermasalah. Coba lagi nanti.';
    default:
      debugPrint('[Dio] ${e.type}: ${e.message}');
      return 'Koneksi bermasalah. Periksa internet Anda, lalu coba lagi.';
  }
}
