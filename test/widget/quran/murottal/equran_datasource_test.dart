import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';

import 'package:flutter_portfolio/Quran/data/datasources/equran_remote_datasource.dart';
import 'package:flutter_portfolio/Quran/data/models/surah_audio_model.dart';
import 'package:flutter_portfolio/Quran/data/models/tafsir_response_model.dart';
import 'package:flutter_portfolio/Quran/domain/entities/qari.dart';
import 'package:flutter_portfolio/Quran/domain/entities/tafsir.dart';

class MockDio extends Mock implements Dio {}
class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

/// Helper: buat response Dio palsu.
Response<Map<String, dynamic>> _fakeResponse(Map<String, dynamic> data) =>
    Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: ''),
    );

void main() {
  group('Qari entity', () {
    test('all berisi 6 qari', () {
      expect(Qari.all.length, 6);
    });

    test('setiap qari memiliki id, name, slug tidak kosong', () {
      for (final q in Qari.all) {
        expect(q.id.isNotEmpty, true, reason: 'id kosong: $q');
        expect(q.name.isNotEmpty, true, reason: 'name kosong: $q');
        expect(q.slug.isNotEmpty, true, reason: 'slug kosong: $q');
      }
    });

    test('defaultQari adalah id 05', () {
      expect(Qari.defaultQari.id, '05');
    });

    test('fromId mengembalikan qari yang tepat', () {
      expect(Qari.fromId('01').name, 'Abdullah Al-Juhany');
      expect(Qari.fromId('03').name, 'Abdurrahman As-Sudais');
      expect(Qari.fromId('06').name, 'Yasser Al-Dosari');
    });

    test('fromId mengembalikan default jika id tidak ditemukan', () {
      expect(Qari.fromId('99').id, Qari.defaultQari.id);
    });

    test('equality berdasarkan id', () {
      const a = Qari(id: '01', name: 'A', slug: 'a');
      const b = Qari(id: '01', name: 'B', slug: 'b');
      expect(a, equals(b));
    });
  });

  group('Tafsir entity', () {
    test('fromJson parse dengan benar', () {
      final t = Tafsir.fromJson({'ayat': 3, 'teks': 'Tafsir ayat 3...'});
      expect(t.ayat, 3);
      expect(t.teks, 'Tafsir ayat 3...');
    });

    test('equality berdasarkan nomor ayat', () {
      const a = Tafsir(ayat: 1, teks: 'A');
      const b = Tafsir(ayat: 1, teks: 'B berbeda');
      expect(a, equals(b));
    });
  });

  group('SurahAudioModel', () {
    late Map<String, dynamic> _sampleJson;

    setUp(() {
      _sampleJson = {
        'data': {
          'nomor': 1,
          'audioFull': {
            '01': 'https://cdn.equran.id/audio-full/Abdullah-Al-Juhany/001.mp3',
            '05': 'https://cdn.equran.id/audio-full/Misyari-Rasyid-Al-Afasi/001.mp3',
          },
          'ayat': [
            {
              'nomorAyat': 1,
              'audio': {
                '01': 'https://cdn.equran.id/audio-partial/Abdullah-Al-Juhany/001001.mp3',
                '05': 'https://cdn.equran.id/audio-partial/Misyari-Rasyid-Al-Afasi/001001.mp3',
              },
            },
            {
              'nomorAyat': 2,
              'audio': {
                '01': 'https://cdn.equran.id/audio-partial/Abdullah-Al-Juhany/001002.mp3',
                '05': 'https://cdn.equran.id/audio-partial/Misyari-Rasyid-Al-Afasi/001002.mp3',
              },
            },
          ],
        },
      };
    });

    test('fromJson parse nomor dan audioFull', () {
      final model = SurahAudioModel.fromJson(_sampleJson);
      expect(model.nomor, 1);
      expect(model.audioFull['01'], contains('Abdullah-Al-Juhany'));
      expect(model.audioFull['05'], contains('Misyari-Rasyid-Al-Afasi'));
    });

    test('fromJson parse ayat list', () {
      final model = SurahAudioModel.fromJson(_sampleJson);
      expect(model.ayat.length, 2);
      expect(model.ayat[0].nomorAyat, 1);
      expect(model.ayat[1].nomorAyat, 2);
    });

    test('audioFullUrl mengembalikan URL yang tepat per qari', () {
      final model = SurahAudioModel.fromJson(_sampleJson);
      expect(model.audioFullUrl('01'), contains('Abdullah-Al-Juhany/001.mp3'));
      expect(model.audioFullUrl('05'), contains('Misyari-Rasyid-Al-Afasi/001.mp3'));
      expect(model.audioFullUrl('99'), isNull);
    });

    test('AyatAudioModel.audioUrl mengembalikan URL yang tepat', () {
      final model = SurahAudioModel.fromJson(_sampleJson);
      final ayat1 = model.ayat[0];
      expect(ayat1.audioUrl('01'), contains('001001.mp3'));
      expect(ayat1.audioUrl('05'), contains('Misyari-Rasyid-Al-Afasi/001001.mp3'));
      expect(ayat1.audioUrl('99'), isNull);
    });
  });

  group('TafsirResponseModel', () {
    test('fromJson parse nomor dan list tafsir', () {
      final json = {
        'data': {
          'nomor': 1,
          'tafsir': [
            {'ayat': 1, 'teks': 'Tafsir ayat pertama...'},
            {'ayat': 2, 'teks': 'Tafsir ayat kedua...'},
          ],
        },
      };
      final model = TafsirResponseModel.fromJson(json);
      expect(model.nomor, 1);
      expect(model.tafsir.length, 2);
      expect(model.tafsir[0].ayat, 1);
      expect(model.tafsir[1].teks, 'Tafsir ayat kedua...');
    });

    test('fromJson toleran jika tafsir kosong', () {
      final json = {'data': {'nomor': 9, 'tafsir': []}};
      final model = TafsirResponseModel.fromJson(json);
      expect(model.tafsir, isEmpty);
    });
  });

  group('EquranRemoteDataSource', () {
    late MockDio mockDio;
    late EquranRemoteDataSourceImpl datasource;

    setUp(() {
      mockDio = MockDio();
      datasource = EquranRemoteDataSourceImpl(dio: mockDio);

      // Setup default options agar Dio.options tidak null
      when(() => mockDio.options).thenReturn(BaseOptions());
    });

    test('getSurahAudio berhasil parse response', () async {
      final responseData = {
        'data': {
          'nomor': 1,
          'audioFull': {
            '05': 'https://cdn.equran.id/audio-full/Misyari-Rasyid-Al-Afasi/001.mp3',
          },
          'ayat': [
            {
              'nomorAyat': 1,
              'audio': {
                '05': 'https://cdn.equran.id/audio-partial/Misyari-Rasyid-Al-Afasi/001001.mp3',
              },
            },
          ],
        },
      };

      when(() => mockDio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => _fakeResponse(responseData));

      final result = await datasource.getSurahAudio(1);
      expect(result.nomor, 1);
      expect(result.audioFullUrl('05'), isNotNull);
      expect(result.ayat.length, 1);
    });

    test('getTafsir berhasil parse response', () async {
      final responseData = {
        'data': {
          'nomor': 1,
          'tafsir': [
            {'ayat': 1, 'teks': 'Bismillah dimulai dengan...'},
          ],
        },
      };

      when(() => mockDio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => _fakeResponse(responseData));

      final result = await datasource.getTafsir(1);
      expect(result.nomor, 1);
      expect(result.tafsir.length, 1);
      expect(result.tafsir[0].ayat, 1);
    });

    test('getSurahAudio lempar EquranApiException saat DioException', () async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/surat/1'),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(
        () => datasource.getSurahAudio(1),
        throwsA(isA<EquranApiException>()),
      );
    });

    test('getTafsir lempar EquranApiException saat timeout', () async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/tafsir/1'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(
        () => datasource.getTafsir(1),
        throwsA(isA<EquranApiException>()),
      );
    });
  });
}
