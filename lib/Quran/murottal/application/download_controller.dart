import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

/// Siap download: menunggu konfirmasi user.
class DownloadReady extends DownloadState {
  const DownloadReady({
    required this.fileSizeBytes,
    this.onMobileData = false,
    this.lowSpace = false,
  });

  /// Perkiraan ukuran (bukan hasil HEAD), lihat [DownloadController.estimateBytes].
  final int fileSizeBytes;
  final bool onMobileData;

  /// Ruang kosong tidak cukup: unduhan tidak boleh dimulai.
  final bool lowSpace;

  /// Data seluler + unduhan besar: perlu peringatan kuota sebelum lanjut.
  bool get needsMobileConfirm =>
      onMobileData && fileSizeBytes > DownloadController.mobileWarnBytes;

  String get fileSizeLabel {
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Ada unduhan format lama (satu file surah) yang tidak bisa diputar lagi.
class DownloadNeedsRedownload extends DownloadState {
  const DownloadNeedsRedownload();
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

  /// Kemajuan dalam jumlah ayat (received = ayat selesai, total = semua ayat).
  String get receivedLabel => '$received dari $total ayat';
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
/// State: [DownloadIdle] -> [DownloadCheckingSize] -> [DownloadReady] ->
///        [DownloadInProgress] -> [DownloadCompleted] / [DownloadError]
class DownloadController extends ValueNotifier<DownloadState> {
  DownloadController({
    required AudioLocalDataSource localDataSource,
    Future<int?> Function()? freeSpace,
    Future<bool> Function()? onMobileData,
  })  : _local = localDataSource,
        _freeSpace = freeSpace ?? _channelFreeSpace,
        _onMobileData = onMobileData ?? _connectivityIsMobile,
        super(const DownloadIdle());

  final AudioLocalDataSource _local;
  final Future<int?> Function() _freeSpace;
  final Future<bool> Function() _onMobileData;
  CancelToken? _cancelToken;

  /// Di atas ukuran ini, data seluler butuh konfirmasi (50 MB).
  static const mobileWarnBytes = 50 * 1024 * 1024;

  // shortcut: rata-rata byte/ayat per qari dari total terukur 6236 ayat
  // (report R&D 2026-11-08); ukuran asli per surah bisa meleset +-50%,
  // upgrade ke HEAD per file bila perlu angka pasti.
  static const _avgBytesPerAyat = {
    '01': 201 * 1024,
    '02': 283 * 1024,
    '03': 296 * 1024,
    '04': 240 * 1024,
    '05': 274 * 1024,
    '06': 239 * 1024,
  };

  /// Perkiraan ukuran unduhan satu surah.
  static int estimateBytes(String qariId, int verseCount) =>
      verseCount * (_avgBytesPerAyat[qariId] ?? 274 * 1024);

  static const _storageChannel = MethodChannel('quran.murojaah/storage');

  /// Ruang kosong (bytes) via kanal native; null = tidak diketahui (cek dilewati).
  static Future<int?> _channelFreeSpace() async {
    try {
      return await _storageChannel.invokeMethod<int>('freeBytes');
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _connectivityIsMobile() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.contains(ConnectivityResult.mobile) &&
          !r.contains(ConnectivityResult.wifi) &&
          !r.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

  /// Inisialisasi: cek apakah surah sudah lengkap di lokal.
  Future<void> checkIfDownloaded(
      String qariId, int surahNumber, int verseCount) async {
    if (await _local.isSurahComplete(qariId, surahNumber, verseCount)) {
      value = DownloadCompleted(
        filePath: await _local.ayatPath(qariId, surahNumber, 1),
        fileSizeBytes: await _surahSize(qariId, surahNumber),
      );
    } else if (await _local.hasLegacy(qariId, surahNumber)) {
      value = const DownloadNeedsRedownload();
    } else {
      value = const DownloadIdle();
    }
  }

  Future<int> _surahSize(String qariId, int surahNumber) async {
    final all = await _local.listDownloaded();
    return all
            .where((f) =>
                f.qariId == qariId && f.surahNumber == surahNumber && !f.isLegacy)
            .firstOrNull
            ?.fileSizeBytes ??
        0;
  }

  /// Langkah 1: hitung perkiraan ukuran, cek ruang kosong dan jenis jaringan.
  Future<void> prepare(String qariId, int verseCount) async {
    value = const DownloadCheckingSize();
    final size = estimateBytes(qariId, verseCount);
    final free = await _freeSpace();
    final mobile = await _onMobileData();
    value = DownloadReady(
      fileSizeBytes: size,
      onMobileData: mobile,
      // Sisakan 20% untuk file sementara dan sistem.
      lowSpace: free != null && free < size * 1.2,
    );
  }

  /// Langkah 2: mulai download setelah user konfirmasi.
  Future<void> startDownload({
    required String qariId,
    required int surahNumber,
    required int verseCount,
  }) async {
    final ready = value;
    if (ready is DownloadReady && ready.lowSpace) return;

    _cancelToken = CancelToken();
    final startTime = DateTime.now();
    value = DownloadInProgress(received: 0, total: verseCount, startTime: startTime);

    try {
      await _local.downloadSurah(
        qariId: qariId,
        surahNumber: surahNumber,
        verseCount: verseCount,
        cancelToken: _cancelToken,
        onProgress: (done, total) {
          if (!(_cancelToken?.isCancelled ?? false)) {
            value = DownloadInProgress(
                received: done, total: total, startTime: startTime);
          }
        },
      );
      value = DownloadCompleted(
        filePath: await _local.ayatPath(qariId, surahNumber, 1),
        fileSizeBytes: await _surahSize(qariId, surahNumber),
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        value = const DownloadIdle();
      } else {
        debugPrint('[Download] gagal: ${e.message}');
        value = const DownloadError(_failMessage);
      }
    } catch (e) {
      debugPrint('[Download] gagal: $e');
      value = const DownloadError(_failMessage);
    }
  }

  static const _failMessage =
      'Unduhan gagal. Periksa internet dan ruang penyimpanan, lalu coba lagi. '
      'Ayat yang sudah terunduh tidak perlu diunduh ulang.';

  /// Batalkan download yang sedang berjalan.
  void cancelDownload() {
    _cancelToken?.cancel('Dibatalkan user');
    _cancelToken = null;
  }

  /// Reset ke DownloadIdle.
  void setIdle() => value = const DownloadIdle();

  /// Hapus file lokal dan reset ke idle.
  Future<void> deleteDownload(String qariId, int surahNumber) async {
    await _local.deleteSurah(qariId, surahNumber);
    value = const DownloadIdle();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Controller disposed');
    super.dispose();
  }
}
