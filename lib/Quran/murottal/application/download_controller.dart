import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/datasources/audio_local_datasource.dart';

/// State download audio murottal untuk satu surah.
sealed class DownloadState {
  const DownloadState();
}

/// Belum ada aktivitas download.
class DownloadIdle extends DownloadState {
  const DownloadIdle();
}

/// Sedang mengambil ukuran file via HEAD request.
class DownloadCheckingSize extends DownloadState {
  const DownloadCheckingSize();
}

/// Siap download — ukuran file sudah diketahui, menunggu konfirmasi user.
class DownloadReady extends DownloadState {
  const DownloadReady({required this.fileSizeBytes});
  final int fileSizeBytes;

  String get fileSizeLabel {
    if (fileSizeBytes < 0) return 'Ukuran tidak diketahui';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Sedang dalam proses download.
class DownloadInProgress extends DownloadState {
  const DownloadInProgress({
    required this.received,
    required this.total,
    required this.startTime,
  });

  final int received;
  final int total;
  final DateTime startTime;

  /// Progress 0.0–1.0. Null jika total tidak diketahui.
  double? get progress => total > 0 ? received / total : null;

  /// Persentase 0–100. Null jika total tidak diketahui.
  int? get percent {
    final p = progress;
    if (p == null) return null;
    return (p * 100).round();
  }

  /// Estimasi sisa waktu. Null jika belum bisa dihitung.
  Duration? get eta {
    final p = progress;
    if (p == null || p <= 0) return null;
    final elapsed = DateTime.now().difference(startTime);
    final totalEstimated = elapsed.inMilliseconds / p;
    final remaining = totalEstimated - elapsed.inMilliseconds;
    if (remaining <= 0) return Duration.zero;
    return Duration(milliseconds: remaining.round());
  }

  /// Format ETA ke string yang mudah dibaca.
  String get etaLabel {
    final e = eta;
    if (e == null) return '';
    if (e.inSeconds < 60) return '${e.inSeconds}d';
    return '${e.inMinutes}m ${e.inSeconds % 60}d';
  }

  /// Format bytes yang sudah diunduh.
  String get receivedLabel {
    if (received < 1024 * 1024) return '${(received / 1024).toStringAsFixed(1)} KB';
    return '${(received / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Download selesai — file tersimpan lokal.
class DownloadCompleted extends DownloadState {
  const DownloadCompleted({
    required this.filePath,
    required this.fileSizeBytes,
  });

  final String filePath;
  final int fileSizeBytes;

  String get fileSizeLabel {
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Download gagal.
class DownloadError extends DownloadState {
  const DownloadError(this.message);
  final String message;
}

/// Controller download audio murottal untuk satu surah.
///
/// Satu instance per surah detail page.
/// State: [DownloadIdle] → [DownloadCheckingSize] → [DownloadReady] →
///        [DownloadInProgress] → [DownloadCompleted] / [DownloadError]
class DownloadController extends ValueNotifier<DownloadState> {
  DownloadController({required AudioLocalDataSource localDataSource})
      : _local = localDataSource,
        super(const DownloadIdle());

  final AudioLocalDataSource _local;
  CancelToken? _cancelToken;

  /// Inisialisasi: cek apakah file sudah ada lokal.
  /// Dipanggil dari initState page.
  Future<void> checkIfDownloaded(String qariId, int surahNumber) async {
    final path = await _local.getLocalPath(qariId, surahNumber);
    if (path != null) {
      final size = await _local.getTotalStorageUsed();
      // Ambil ukuran file spesifik ini
      final info = await _local.listDownloaded();
      final match = info
          .where((f) => f.qariId == qariId && f.surahNumber == surahNumber)
          .firstOrNull;
      value = DownloadCompleted(
        filePath: path,
        fileSizeBytes: match?.fileSizeBytes ?? size,
      );
    } else {
      value = const DownloadIdle();
    }
  }

  /// Langkah 1: Ambil ukuran file dari server (HEAD request).
  /// State berubah ke [DownloadCheckingSize] lalu [DownloadReady].
  Future<void> checkSize(String url) async {
    value = const DownloadCheckingSize();
    final size = await _local.getRemoteFileSize(url);
    value = DownloadReady(fileSizeBytes: size);
  }

  /// Langkah 2: Mulai download setelah user konfirmasi.
  Future<void> startDownload({
    required String url,
    required String qariId,
    required int surahNumber,
  }) async {
    _cancelToken = CancelToken();
    final startTime = DateTime.now();
    value = DownloadInProgress(received: 0, total: -1, startTime: startTime);

    try {
      final path = await _local.download(
        url: url,
        qariId: qariId,
        surahNumber: surahNumber,
        cancelToken: _cancelToken,
        onProgress: (received, total) {
          if (!(_cancelToken?.isCancelled ?? false)) {
            value = DownloadInProgress(
              received: received,
              total: total,
              startTime: startTime,
            );
          }
        },
      );
      final info = await _local.listDownloaded();
      final match = info
          .where((f) => f.qariId == qariId && f.surahNumber == surahNumber)
          .firstOrNull;
      value = DownloadCompleted(
        filePath: path,
        fileSizeBytes: match?.fileSizeBytes ?? 0,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        value = const DownloadIdle();
      } else {
        value = DownloadError('Download gagal: ${e.message ?? 'Kesalahan jaringan'}');
      }
    } catch (e) {
      value = DownloadError('Download gagal: $e');
    }
  }

  /// Batalkan download yang sedang berjalan.
  void cancelDownload() {
    _cancelToken?.cancel('Dibatalkan user');
    _cancelToken = null;
  }

  /// Set state ke DownloadCheckingSize secara manual (sebelum API call).
  void setChecking() => value = const DownloadCheckingSize();

  /// Reset ke DownloadIdle (misal saat API call gagal sebelum checkSize).
  void setIdle() => value = const DownloadIdle();

  /// Hapus file lokal dan reset ke idle.
  Future<void> deleteDownload(String qariId, int surahNumber) async {
    await _local.delete(qariId, surahNumber);
    value = const DownloadIdle();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Controller disposed');
    super.dispose();
  }
}
