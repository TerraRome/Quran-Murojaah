import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Penjaga: tidak ada warna hardcode di modul murojaah.
///
/// Warna harus datang dari `QuranTokens` supaya mode terang/gelap dan kontras
/// WCAG hanya diurus di satu tempat. Test ini memindai sumber, jadi warna
/// literal yang lolos review tetap akan gagal di CI.
void main() {
  final root = Directory('lib/Quran/murojaah');

  Iterable<File> dartFiles() => root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  test('folder murojaah ada', () {
    expect(root.existsSync(), isTrue, reason: 'jalankan test dari root repo');
  });

  test('tidak ada Color(0x…) di lib/Quran/murojaah', () {
    final hits = <String>[];
    final pattern = RegExp(r'Color\(0x');
    for (final file in dartFiles()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          hits.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('tidak ada Colors.white / Colors.black / Colors.red di murojaah', () {
    final hits = <String>[];
    final pattern = RegExp(r'Colors\.(white|black|red|green|grey|amber)');
    for (final file in dartFiles()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          hits.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
