import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Informasi file audio yang tersimpan lokal.
class LocalAudioInfo {
  const LocalAudioInfo({
    required this.filePath,
    required this.fileSizeBytes,
    required this.qariId,
    required this.surahNumber,
  });

  final String filePath;
  final int fileSizeBytes;
  final String qariId;
  final int surahNumber;

  /// Format ukuran file ke string yang mudah dibaca (mis. "4.2 MB").
  String get fileSizeLabel {
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Callback progress download: received bytes, total bytes (-1 jika tidak diketahui).
typedef DownloadProgressCallback = void Function(int received, int total);

/// Data source untuk operasi file audio lokal.
///
/// Semua file disimpan di:
/// `{appDocDir}/murottal/{qariId}/{surahNumber padded 3 digit}.mp3`
abstract class AudioLocalDataSource {
  /// Cek apakah file sudah ada di lokal untuk qari dan surah tertentu.
  Future<bool> isDownloaded(String qariId, int surahNumber);

  /// Ambil path file lokal. Kembalikan null jika belum ada.
  Future<String?> getLocalPath(String qariId, int surahNumber);

  /// Ambil ukuran file remote via HEAD request (Content-Length).
  /// Kembalikan -1 jika server tidak mengembalikan Content-Length.
  Future<int> getRemoteFileSize(String url);

  /// Download file dari [url] dan simpan lokal.
  /// Progress dilaporkan via [onProgress].
  Future<String> download({
    required String url,
    required String qariId,
    required int surahNumber,
    DownloadProgressCallback? onProgress,
    CancelToken? cancelToken,
  });

  /// Hapus file lokal untuk qari dan surah tertentu.
  Future<void> delete(String qariId, int surahNumber);

  /// Hapus semua file lokal untuk semua qari dan surah.
  Future<void> deleteAll();

  /// Daftar semua file yang sudah didownload.
  Future<List<LocalAudioInfo>> listDownloaded();

  /// Total ukuran semua file yang tersimpan lokal (bytes).
  Future<int> getTotalStorageUsed();
}

class AudioLocalDataSourceImpl implements AudioLocalDataSource {
  AudioLocalDataSourceImpl({Dio? dio}) : _dio = dio ?? _buildDio();

  final Dio _dio;

  static Dio _buildDio() => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 10),
        ),
      );

  /// Bangun path direktori untuk satu qari.
  Future<Directory> _qariDir(String qariId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/murottal/$qariId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Nama file: surahNumber zero-padded 3 digit, mis. "001.mp3".
  String _fileName(int surahNumber) =>
      '${surahNumber.toString().padLeft(3, '0')}.mp3';

  /// Path lengkap file lokal.
  Future<String> _filePath(String qariId, int surahNumber) async {
    final dir = await _qariDir(qariId);
    return '${dir.path}/${_fileName(surahNumber)}';
  }

  @override
  Future<bool> isDownloaded(String qariId, int surahNumber) async {
    final path = await _filePath(qariId, surahNumber);
    return File(path).exists();
  }

  @override
  Future<String?> getLocalPath(String qariId, int surahNumber) async {
    final path = await _filePath(qariId, surahNumber);
    final file = File(path);
    if (await file.exists()) return path;
    return null;
  }

  @override
  Future<int> getRemoteFileSize(String url) async {
    try {
      final response = await _dio.head<dynamic>(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      final contentLength = response.headers.value('content-length');
      if (contentLength != null) {
        return int.tryParse(contentLength) ?? -1;
      }
      return -1;
    } catch (_) {
      return -1;
    }
  }

  @override
  Future<String> download({
    required String url,
    required String qariId,
    required int surahNumber,
    DownloadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final path = await _filePath(qariId, surahNumber);
    final tempPath = '$path.tmp';

    try {
      await _dio.download(
        url,
        tempPath,
        cancelToken: cancelToken,
        onReceiveProgress: onProgress,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      // Rename temp → final hanya jika selesai sempurna
      await File(tempPath).rename(path);
      return path;
    } catch (e) {
      // Bersihkan temp file jika gagal / dibatalkan
      final tmp = File(tempPath);
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }

  @override
  Future<void> delete(String qariId, int surahNumber) async {
    final path = await _filePath(qariId, surahNumber);
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> deleteAll() async {
    final base = await getApplicationDocumentsDirectory();
    final murottalDir = Directory('${base.path}/murottal');
    if (await murottalDir.exists()) {
      await murottalDir.delete(recursive: true);
    }
  }

  @override
  Future<List<LocalAudioInfo>> listDownloaded() async {
    final base = await getApplicationDocumentsDirectory();
    final murottalDir = Directory('${base.path}/murottal');
    if (!await murottalDir.exists()) return [];

    final result = <LocalAudioInfo>[];
    await for (final qariEntity in murottalDir.list()) {
      if (qariEntity is! Directory) continue;
      final qariId = qariEntity.path.split('/').last;
      await for (final fileEntity in qariEntity.list()) {
        if (fileEntity is! File) continue;
        final name = fileEntity.path.split('/').last;
        if (!name.endsWith('.mp3')) continue;
        final numberStr = name.replaceAll('.mp3', '');
        final surahNumber = int.tryParse(numberStr);
        if (surahNumber == null) continue;
        final size = await fileEntity.length();
        result.add(LocalAudioInfo(
          filePath: fileEntity.path,
          fileSizeBytes: size,
          qariId: qariId,
          surahNumber: surahNumber,
        ));
      }
    }
    result.sort((a, b) {
      final qariCmp = a.qariId.compareTo(b.qariId);
      if (qariCmp != 0) return qariCmp;
      return a.surahNumber.compareTo(b.surahNumber);
    });
    return result;
  }

  @override
  Future<int> getTotalStorageUsed() async {
    final files = await listDownloaded();
    return files.fold<int>(0, (sum, f) => sum + f.fileSizeBytes);
  }
}
