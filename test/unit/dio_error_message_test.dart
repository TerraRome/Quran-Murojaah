import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/data/network/dio_error_message.dart';

void main() {
  DioException err(DioExceptionType type, {Response<dynamic>? response}) =>
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: type,
        response: response,
        message: 'boom',
      );

  test('timeout koneksi', () {
    expect(
      dioErrorMessage(err(DioExceptionType.connectionTimeout)),
      'Koneksi timeout. Periksa koneksi internet Anda.',
    );
    expect(
      dioErrorMessage(err(DioExceptionType.receiveTimeout)),
      'Koneksi timeout. Periksa koneksi internet Anda.',
    );
  });

  test('tanpa koneksi', () {
    expect(
      dioErrorMessage(err(DioExceptionType.connectionError)),
      'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
    );
  });

  test('status error', () {
    final e = err(
      DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 503,
      ),
    );
    expect(dioErrorMessage(e), 'Server mengembalikan error 503.');
  });

  test('lainnya memakai pesan asli', () {
    expect(
      dioErrorMessage(err(DioExceptionType.unknown)),
      'Terjadi kesalahan jaringan: boom',
    );
  });
}
