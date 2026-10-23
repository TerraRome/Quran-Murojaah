import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Berbagi berkas cadangan lewat lembar berbagi sistem.
///
/// Antarmuka tipis supaya test tidak menyentuh plugin.
abstract class BackupSharer {
  /// Bagikan [json] sebagai berkas .json. False = pengguna membatalkan atau
  /// platform tidak mendukung.
  Future<bool> share(String json);
}

/// Implementasi nyata: tulis ke berkas sementara, lalu buka share sheet.
///
/// Tidak ada `file_picker`: impor memakai tempel teks.
class SharePlusBackupSharer implements BackupSharer {
  const SharePlusBackupSharer();

  @override
  Future<bool> share(String json) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 19)
        .replaceAll(RegExp(r'[:T]'), '-');
    final file = File('${dir.path}/murojaah-$stamp.json');
    await file.writeAsString(json, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Cadangan murojaah',
        text: 'Cadangan progres murojaah.',
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }
}
