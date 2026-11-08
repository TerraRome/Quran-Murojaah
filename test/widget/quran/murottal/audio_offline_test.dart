import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/data/datasources/audio_local_datasource.dart';
import 'package:quran/Quran/domain/entities/qari.dart';
import 'package:quran/Quran/murottal/application/download_controller.dart';

void main() {
  late Directory tmp;
  late List<String> fetched;
  late AudioLocalDataSourceImpl local;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('murottal_test');
    fetched = [];
    local = AudioLocalDataSourceImpl(
      baseDir: () async => tmp,
      fetcher: (url, path, _) async {
        fetched.add(url);
        await File(path).writeAsBytes([1, 2, 3]);
      },
    );
  });
  tearDown(() => tmp.delete(recursive: true));

  group('layout & kelengkapan', () {
    test('path per ayat: murottal/{qari}/{SSS}/{AAA}.mp3', () async {
      expect(await local.ayatPath('05', 2, 7),
          '${tmp.path}/murottal/05/002/007.mp3');
    });

    test('URL ayat memakai slug qari dan SSSAAA', () {
      expect(AudioLocalDataSourceImpl.ayatUrl(Qari.defaultQari, 2, 255),
          'https://cdn.equran.id/audio-partial/Misyari-Rasyid-Al-Afasi/002255.mp3');
    });

    test('lengkap hanya bila semua ayat ada dan tidak kosong', () async {
      await local.downloadSurah(qariId: '05', surahNumber: 1, verseCount: 7);
      expect(await local.isSurahComplete('05', 1, 7), isTrue);
      expect(await local.isSurahComplete('05', 1, 8), isFalse);
      expect(await local.isSurahComplete('05', 1, 0), isFalse);
      await File(await local.ayatPath('05', 1, 3)).writeAsBytes([]);
      expect(await local.isSurahComplete('05', 1, 7), isFalse);
    });

    test('listDownloaded membaca ayat per folder, bukan 002001 sebagai surah 2001',
        () async {
      await local.downloadSurah(qariId: '05', surahNumber: 2, verseCount: 3);
      final all = await local.listDownloaded();
      expect(all.length, 1);
      expect(
          (all.single.surahNumber, all.single.fileCount, all.single.isLegacy),
          (2, 3, false));
    });
  });

  group('unduh', () {
    test('resume: ayat yang sudah ada dilewati; progress = ayat selesai/total',
        () async {
      await Directory('${tmp.path}/murottal/05/001').create(recursive: true);
      await File(await local.ayatPath('05', 1, 1)).writeAsBytes([9]);
      await File(await local.ayatPath('05', 1, 2)).writeAsBytes([9]);
      final progress = <int>[];
      await local.downloadSurah(
        qariId: '05',
        surahNumber: 1,
        verseCount: 4,
        onProgress: (done, total) => progress.add(done),
      );
      expect(fetched.length, 2);
      expect(fetched.any((u) => u.endsWith('001001.mp3')), isFalse);
      expect(progress.last, 4);
      expect(await local.isSurahComplete('05', 1, 4), isTrue);
    });

    test('gagal: tidak ada .tmp tersisa', () async {
      final bad = AudioLocalDataSourceImpl(
        baseDir: () async => tmp,
        fetcher: (url, path, _) async {
          await File(path).writeAsBytes([1]);
          if (url.endsWith('001003.mp3')) {
            throw DioException(requestOptions: RequestOptions());
          }
        },
      );
      await expectLater(
          bad.downloadSurah(qariId: '05', surahNumber: 1, verseCount: 3),
          throwsA(isA<DioException>()));
      final names = Directory('${tmp.path}/murottal/05/001')
          .listSync()
          .map((e) => e.path.split('/').last);
      expect(names.any((n) => n.endsWith('.tmp')), isFalse);
    });

    test('file lama NNN.mp3: terdeteksi, dihapus setelah unduh baru sukses',
        () async {
      await Directory('${tmp.path}/murottal/05').create(recursive: true);
      await File('${tmp.path}/murottal/05/001.mp3').writeAsBytes([1, 2]);
      expect(await local.hasLegacy('05', 1), isTrue);
      expect((await local.listDownloaded()).single.isLegacy, isTrue);
      expect(await local.isSurahComplete('05', 1, 2), isFalse);

      await local.downloadSurah(qariId: '05', surahNumber: 1, verseCount: 2);
      expect(await local.hasLegacy('05', 1), isFalse);
      expect(await local.isSurahComplete('05', 1, 2), isTrue);
    });

    test('ganti qari: unduhan qari lain tetap; deleteSurah hanya satu qari',
        () async {
      await local.downloadSurah(qariId: '05', surahNumber: 1, verseCount: 2);
      await local.downloadSurah(qariId: '01', surahNumber: 1, verseCount: 2);
      await local.deleteSurah('05', 1);
      expect(await local.isSurahComplete('05', 1, 2), isFalse);
      expect(await local.isSurahComplete('01', 1, 2), isTrue);
    });
  });

  group('DownloadController', () {
    DownloadController make({int? free, bool mobile = false}) =>
        DownloadController(
          localDataSource: local,
          freeSpace: () async => free,
          onMobileData: () async => mobile,
        );

    test('ruang kosong kurang: Ready.lowSpace dan unduhan tidak dimulai',
        () async {
      final c = make(free: 1024);
      await c.prepare('05', 7);
      expect((c.value as DownloadReady).lowSpace, isTrue);
      await c.startDownload(qariId: '05', surahNumber: 1, verseCount: 7);
      expect(c.value, isA<DownloadReady>());
      expect(fetched, isEmpty);
    });

    test('ruang tidak diketahui (null): tidak memblokir', () async {
      final c = make();
      await c.prepare('05', 7);
      expect((c.value as DownloadReady).lowSpace, isFalse);
    });

    test('data seluler > 50 MB minta konfirmasi; kecil atau Wi-Fi tidak',
        () async {
      final c = make(mobile: true);
      await c.prepare('05', 286); // Al-Baqarah, ~76 MB perkiraan
      expect((c.value as DownloadReady).needsMobileConfirm, isTrue);
      await c.prepare('05', 7);
      expect((c.value as DownloadReady).needsMobileConfirm, isFalse);
      final wifi = make();
      await wifi.prepare('05', 286);
      expect((wifi.value as DownloadReady).needsMobileConfirm, isFalse);
    });

    test('unduh sukses -> Completed; surah lama -> NeedsRedownload', () async {
      await Directory('${tmp.path}/murottal/05').create(recursive: true);
      await File('${tmp.path}/murottal/05/001.mp3').writeAsBytes([1]);
      final c = make();
      await c.checkIfDownloaded('05', 1, 3);
      expect(c.value, isA<DownloadNeedsRedownload>());
      await c.startDownload(qariId: '05', surahNumber: 1, verseCount: 3);
      expect(c.value, isA<DownloadCompleted>());
      expect((c.value as DownloadCompleted).fileSizeBytes, 9);
    });

    test('gagal: pesan ramah, bukan detail teknis', () async {
      final failing = AudioLocalDataSourceImpl(
        baseDir: () async => tmp,
        fetcher: (a, b, c) async => throw const SocketException('x'),
      );
      final c = DownloadController(localDataSource: failing);
      await c.startDownload(qariId: '05', surahNumber: 1, verseCount: 2);
      final msg = (c.value as DownloadError).message;
      expect(msg, startsWith('Unduhan gagal'));
      expect(msg, isNot(contains('SocketException')));
    });
  });
}
