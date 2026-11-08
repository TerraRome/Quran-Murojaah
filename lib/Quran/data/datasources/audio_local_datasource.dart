import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/qari.dart';

/// Ringkasan satu surah yang tersimpan lokal untuk satu qari.
class LocalAudioInfo {
  const LocalAudioInfo({
    required this.filePath,
    required this.fileSizeBytes,
    required this.qariId,
    required this.surahNumber,
    this.fileCount = 0,
    this.isLegacy = false,
  });

  /// Folder surah (layout baru) atau file `NNN.mp3` (layout lama).
  final String filePath;
  final int fileSizeBytes;
  final String qariId;
  final int surahNumber;

  /// Jumlah file ayat yang ada (0 untuk layout lama).
  final int fileCount;

  /// True bila ini file surah utuh lama (`NNN.mp3`): tidak bisa diputar,
  /// perlu diunduh ulang per ayat.
  final bool isLegacy;

  /// Format ukuran file ke string yang mudah dibaca (mis. "4.2 MB").
  String get fileSizeLabel {
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Progress unduh surah: ayat selesai, total ayat.
typedef DownloadProgressCallback = void Function(int done, int total);

/// Mengunduh satu URL ke [path]. Dipisah supaya bisa diganti di test.
typedef FileFetcher = Future<void> Function(
    String url, String path, CancelToken? cancelToken);

/// Data source audio murottal lokal, per ayat.
///
/// Layout: `{appDocDir}/murottal/{qariId}/{SSS}/{AAA}.mp3`.
/// Layout lama (satu file surah): `murottal/{qariId}/{SSS}.mp3`.
abstract class AudioLocalDataSource {
  /// Path file satu ayat (belum tentu ada).
  Future<String> ayatPath(String qariId, int surahNumber, int ayatNumber);

  /// Path file ayat bila ada dan tidak kosong, selain itu null.
  Future<String?> getAyatPath(String qariId, int surahNumber, int ayatNumber);

  /// Surah dianggap terunduh bila SEMUA ayat ada dan tidak kosong.
  Future<bool> isSurahComplete(String qariId, int surahNumber, int verseCount);

  /// Ada file surah utuh format lama yang perlu diunduh ulang.
  Future<bool> hasLegacy(String qariId, int surahNumber);

  /// Unduh semua ayat surah. Ayat yang sudah ada dilewati (resume).
  /// Setelah sukses, file lama `NNN.mp3` dihapus.
  Future<void> downloadSurah({
    required String qariId,
    required int surahNumber,
    required int verseCount,
    DownloadProgressCallback? onProgress,
    CancelToken? cancelToken,
  });

  /// Hapus audio surah (layout baru dan lama) untuk satu qari.
  Future<void> deleteSurah(String qariId, int surahNumber);

  /// Hapus semua audio untuk semua qari.
  Future<void> deleteAll();

  /// Semua surah tersimpan (baru dan lama), terurut qari lalu surah.
  Future<List<LocalAudioInfo>> listDownloaded();

  /// Total ukuran semua file tersimpan (bytes).
  Future<int> getTotalStorageUsed();
}

class AudioLocalDataSourceImpl implements AudioLocalDataSource {
  AudioLocalDataSourceImpl({
    Dio? dio,
    Future<Directory> Function()? baseDir,
    FileFetcher? fetcher,
  })  : _baseDir = baseDir ?? getApplicationDocumentsDirectory,
        _fetch = fetcher ?? _dioFetcher(dio ?? _buildDio());

  final Future<Directory> Function() _baseDir;
  final FileFetcher _fetch;

  /// Jumlah unduhan paralel. Sengaja kecil: CDN equran.id tidak punya cache
  /// edge (cf-cache-status: DYNAMIC), jadi tiap request sampai ke origin.
  static const parallel = 4;

  static Dio _buildDio() => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

  static FileFetcher _dioFetcher(Dio dio) => (url, path, cancelToken) async {
        await dio.download(
          url,
          path,
          cancelToken: cancelToken,
          options: Options(
            followRedirects: true,
            validateStatus: (s) => s != null && s < 400,
          ),
        );
      };

  /// URL audio satu ayat di CDN equran.id.
  static String ayatUrl(Qari qari, int surahNumber, int ayatNumber) =>
      'https://cdn.equran.id/audio-partial/${qari.slug}/'
      '${_pad(surahNumber)}${_pad(ayatNumber)}.mp3';

  static String _pad(int n) => n.toString().padLeft(3, '0');

  Future<String> _murottalPath() async =>
      '${(await _baseDir()).path}/murottal';

  Future<Directory> _surahDir(String qariId, int surahNumber) async =>
      Directory('${await _murottalPath()}/$qariId/${_pad(surahNumber)}');

  Future<File> _legacyFile(String qariId, int surahNumber) async =>
      File('${await _murottalPath()}/$qariId/${_pad(surahNumber)}.mp3');

  @override
  Future<String> ayatPath(
          String qariId, int surahNumber, int ayatNumber) async =>
      '${(await _surahDir(qariId, surahNumber)).path}/${_pad(ayatNumber)}.mp3';

  @override
  Future<String?> getAyatPath(
      String qariId, int surahNumber, int ayatNumber) async {
    final path = await ayatPath(qariId, surahNumber, ayatNumber);
    final f = File(path);
    return await f.exists() && await f.length() > 0 ? path : null;
  }

  @override
  Future<bool> isSurahComplete(
      String qariId, int surahNumber, int verseCount) async {
    if (verseCount <= 0) return false;
    for (var a = 1; a <= verseCount; a++) {
      if (await getAyatPath(qariId, surahNumber, a) == null) return false;
    }
    return true;
  }

  @override
  Future<bool> hasLegacy(String qariId, int surahNumber) async =>
      (await _legacyFile(qariId, surahNumber)).exists();

  @override
  Future<void> downloadSurah({
    required String qariId,
    required int surahNumber,
    required int verseCount,
    DownloadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final qari = Qari.fromId(qariId);
    final dir = await _surahDir(qariId, surahNumber);
    if (!await dir.exists()) await dir.create(recursive: true);

    var done = 0;
    var next = 1;
    onProgress?.call(0, verseCount);

    Future<void> worker() async {
      while (true) {
        if (cancelToken?.isCancelled ?? false) return;
        final ayat = next++;
        if (ayat > verseCount) return;
        // Resume: file lengkap dari unduhan sebelumnya dilewati.
        if (await getAyatPath(qariId, surahNumber, ayat) == null) {
          final path = await ayatPath(qariId, surahNumber, ayat);
          final tmp = '$path.tmp';
          try {
            await _fetch(ayatUrl(qari, surahNumber, ayat), tmp, cancelToken);
            await File(tmp).rename(path);
          } catch (_) {
            final t = File(tmp);
            if (await t.exists()) await t.delete();
            rethrow;
          }
        }
        onProgress?.call(++done, verseCount);
      }
    }

    // Satu worker gagal -> seluruh unduhan gagal; ayat yang sudah selesai
    // tetap tersimpan sehingga percobaan berikutnya melanjutkan.
    await Future.wait([for (var i = 0; i < parallel; i++) worker()]);
    if (cancelToken?.isCancelled ?? false) {
      throw DioException(
          requestOptions: RequestOptions(), type: DioExceptionType.cancel);
    }

    final legacy = await _legacyFile(qariId, surahNumber);
    if (await legacy.exists()) await legacy.delete();
  }

  @override
  Future<void> deleteSurah(String qariId, int surahNumber) async {
    final dir = await _surahDir(qariId, surahNumber);
    if (await dir.exists()) await dir.delete(recursive: true);
    final legacy = await _legacyFile(qariId, surahNumber);
    if (await legacy.exists()) await legacy.delete();
  }

  @override
  Future<void> deleteAll() async {
    final dir = Directory(await _murottalPath());
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  @override
  Future<List<LocalAudioInfo>> listDownloaded() async {
    final root = Directory(await _murottalPath());
    if (!await root.exists()) return [];

    final result = <LocalAudioInfo>[];
    await for (final qariEntity in root.list()) {
      if (qariEntity is! Directory) continue;
      final qariId = qariEntity.path.split('/').last;
      await for (final e in qariEntity.list()) {
        final name = e.path.split('/').last;
        if (e is File && name.endsWith('.mp3')) {
          final n = int.tryParse(name.replaceAll('.mp3', ''));
          if (n == null) continue;
          result.add(LocalAudioInfo(
            filePath: e.path,
            fileSizeBytes: await e.length(),
            qariId: qariId,
            surahNumber: n,
            isLegacy: true,
          ));
        } else if (e is Directory) {
          final n = int.tryParse(name);
          if (n == null) continue;
          var size = 0, count = 0;
          await for (final f in e.list()) {
            if (f is File && f.path.endsWith('.mp3')) {
              size += await f.length();
              count++;
            }
          }
          if (count == 0) continue;
          result.add(LocalAudioInfo(
            filePath: e.path,
            fileSizeBytes: size,
            qariId: qariId,
            surahNumber: n,
            fileCount: count,
          ));
        }
      }
    }
    result.sort((a, b) {
      final c = a.qariId.compareTo(b.qariId);
      return c != 0 ? c : a.surahNumber.compareTo(b.surahNumber);
    });
    return result;
  }

  @override
  Future<int> getTotalStorageUsed() async {
    final files = await listDownloaded();
    return files.fold<int>(0, (sum, f) => sum + f.fileSizeBytes);
  }
}
