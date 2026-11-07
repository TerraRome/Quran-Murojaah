import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/domain/entities/juz.dart';

void main() {
  test('30 juz, urut naik, ayat valid terhadap data bundel', () {
    expect(juzStarts, hasLength(30));
    final data =
        jsonDecode(File('assets/quran/quran.json').readAsStringSync())
            as Map<String, dynamic>;
    final verses = {
      for (final s in data['surahs'] as List<dynamic>)
        (s as Map<String, dynamic>)['number'] as int:
            (s['verses'] as List<dynamic>).length,
    };
    var prev = 0;
    for (final (i, j) in juzStarts.indexed) {
      expect(j.juz, i + 1);
      final pos = j.surah * 1000 + j.ayat;
      expect(pos, greaterThan(prev));
      prev = pos;
      expect(j.ayat, inInclusiveRange(1, verses[j.surah]!));
    }
  });

  test('urutan tampil: Juz 30 dulu, lalu 1..29', () {
    expect(juzDisplayOrder.map((j) => j.juz).toList(), [
      30,
      for (var i = 1; i <= 29; i++) i,
    ]);
  });
}
