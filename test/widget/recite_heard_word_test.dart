import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/recite/asr_snapshot.dart';
import 'package:quran/Quran/murojaah/recite/heard_word.dart';
import 'package:recite_quran/recite_quran.dart';

/// Bukti bahwa event merah dari `recite_quran` tidak pernah membawa teks ASR:
/// `DictationSequencer._commitRed` selalu mengirim `cleanAsr: ''`, baik untuk
/// kata yang salah dibaca (substitusi) maupun yang dilewati.
void main() {
  List<Map<String, dynamic>> redEvents(List<String> words, String asr) {
    final events = <Map<String, dynamic>>[];
    final seq = DictationSequencer(events.add)
      ..fullPhonemes = words.join()
      ..wordBoundaries = _boundaries(words)
      ..isTajweed = false
      ..config = const TrackerConfig();
    seq.syncStream(
      SyncStreamCommand(asrText: asr, timestamps: const [], isNewSegment: true),
    );
    return events.where((e) => e['event'] == 'highlight').toList();
  }

  test('substitusi: event merah tanpa cleanAsr, heardForWord memulihkannya', () {
    const words = ['اا', 'بب', 'جج'];
    final events = redEvents(words, 'ااXXجج');

    final red = events.singleWhere((e) => e['is_red'] == true);
    expect(red['word_id'], 1);
    // Inilah bug-nya: matcher tidak menyertakan token ASR pengganti.
    expect(red['clean_asr'], '');

    // Bunyi pengganti tetap ada di transkrip, hanya "menempel" ke kata
    // berikutnya; rekonstruksi per slot kata memulihkannya.
    expect(
      heardForWord(phonemesPerWord: words, wordIndex: 1, emitted: 'ااXXجج'),
      'XX',
    );
  });

  test('kata dilewati: tidak ada bunyi di slot itu → null', () {
    const words = ['اا', 'بب', 'جج'];
    final events = redEvents(words, 'ااجج');

    final red = events.singleWhere((e) => e['is_red'] == true);
    expect(red['word_id'], 1);
    expect(red['clean_asr'], '');

    expect(
      heardForWord(phonemesPerWord: words, wordIndex: 1, emitted: 'ااجج'),
      isNull,
    );
  });

  test('kata terakhir yang salah baca memakai sisa transkrip', () {
    const words = ['اا', 'بب'];
    expect(
      heardForWord(phonemesPerWord: words, wordIndex: 1, emitted: 'ااZZ'),
      'ZZ',
    );
  });

  test('transkrip kosong → null', () {
    expect(
      heardForWord(phonemesPerWord: const ['اا'], wordIndex: 0, emitted: '  '),
      isNull,
    );
  });

  test('sisa harakat tanpa huruf → null (kata dilewati)', () {
    expect(
      heardForWord(
        phonemesPerWord: const ['بِسمِ', 'للَااهِ', 'ررَحمَاانِ', 'ررَجِۦۦم'],
        wordIndex: 3,
        emitted: 'بِسمِللَااهِررَحمَاانِ',
      ),
      isNull,
    );
  });

  group('slot kata: rentang ASR tidak tumpang tindih', () {
    test('kata A salah + kata B benar → heard B tanpa bunyi A', () {
      // "قُلْ" tidak diucapkan; ASR langsung mengucapkan "نَستَعِينُ" yang benar.
      const words = ['قُلْ', 'نَستَعِينُ'];
      const asr = 'جججنَستَعِينُ';
      expect(
        heardForWord(phonemesPerWord: words, wordIndex: 0, emitted: asr),
        'ججج',
      );
      final b = heardForWord(
        phonemesPerWord: words,
        wordIndex: 1,
        emitted: asr,
      );
      expect(b, 'نَستَعِينُ');
      expect(b!.contains('ج'), isFalse);
    });

    test('rentang tiap kata bersambung dan tidak tumpang tindih', () {
      // `ال` kata berikutnya menyatu ke ekor kata sebelumnya, `ررَ` ganda.
      const words = ['بِسمِ', 'للَااهِ', 'ررَحمَاانِ', 'ررَجِۦۦم'];
      const asr = 'بِسمِللَااهِررَحمَاانِررَجِۦۦم';
      final ranges = wordAsrRanges(phonemesPerWord: words, emitted: asr);

      expect(ranges.length, words.length);
      expect(ranges.first.$1, 0);
      expect(ranges.last.$2, asr.length);
      for (var i = 1; i < ranges.length; i++) {
        expect(ranges[i].$1, ranges[i - 1].$2, reason: 'kata $i tumpang tindih');
      }
      expect(
        heardForWord(phonemesPerWord: words, wordIndex: 3, emitted: asr),
        'ررَجِۦۦم',
      );
    });

    test('awalan transkrip dari ayat sebelumnya tidak ikut slot kata pertama',
        () {
      const words = ['قُلْ', 'هُوَ'];
      const asr = 'اَبْجَدْهَوَّزْقُلْهُوَ';
      expect(
        heardForWord(phonemesPerWord: words, wordIndex: 0, emitted: asr),
        'قُلْ',
      );
    });

    test('asrConsumed: ayat 7 tidak menampilkan bacaan ayat 1', () {
      // Transkrip satu segmen memuat seluruh Al-Fatihah yang sudah dibaca.
      const v1 = ['بِسمِ', 'للَااهِ', 'ررَحمَاانِ', 'ررَجِۦۦم'];
      const v2 = ['اَلحَمدُلِلَااهِ', 'رَبِلعَاالَمِين'];
      const v3 = ['ررَحمَاانِررَجِۦۦم', 'مَاالِكِيَوْمِالدِينِ'];
      const v4 = ['إِيَّاكَنَعبُدُ', 'وَإِيَّاكَنَستَعِينُ'];
      const v5 = ['آهدِنَاالصِرَاطَالمُستَقِيمَ'];
      const v6 = ['صِرَاطَالَّذِين', 'أَنعَمتَعَلَيهِم'];
      const v7 = ['غَيرِالمَغضُوبِ', 'عَلَيهِم', 'وَلَاالضَّآلِّينَ'];

      const before7 = [...v1, ...v2, ...v3, ...v4, ...v5, ...v6];
      const asr = 'بِسمِللَااهِررَحمَاانِررَجِۦۦم'
          'اَلحَمدُلِلَااهِرَبِلعَاالَمِين'
          'ررَحمَاانِررَجِۦۦممَاالِكِيَوْمِالدِينِ'
          'إِيَّاكَنَعبُدُوَإِيَّاكَنَستَعِينُ'
          'آهدِنَاالصِرَاطَالمُستَقِيمَ'
          'صِرَاطَالَّذِينَأَنعَمتَعَلَيهِم'
          'غَيرِالمَغضُوبِعَلَيهِم'
          'وَلَاالضَّآلِّينَ';

      final used = asrConsumed(phonemesPerWord: before7, emitted: asr);
      expect(used, greaterThan(0));
      // Slot kata ayat 7 hanya berisi bunyi ayat 7.
      for (var i = 0; i < v7.length; i++) {
        final heard = heardForWord(
          phonemesPerWord: v7,
          wordIndex: i,
          emitted: asr.substring(used),
        );
        expect(heard, isNotNull, reason: 'kata $i');
        expect(heard!.contains('بِسمِ'), isFalse, reason: 'kata $i bocor ayat 1');
      }
    });
  });

  group('AsrSnapshot: snapshot terikat percobaan', () {
    test('versi terpanjang menang, versi lebih pendek diabaikan', () {
      final snap = AsrSnapshot()..keep(0, 'اا')..keep(0, 'اابب');
      expect(snap.textOf(0), 'اابب');
      snap.keep(0, 'ا');
      expect(snap.textOf(0), 'اابب');
    });

    test('setelah rewind snapshot lama tidak muncul', () {
      final snap = AsrSnapshot()
        ..keep(0, 'اابب')
        ..recordHeard(1, 'XX');
      expect(snap.textOf(0), 'اابب');

      snap.rewind(forgetWords: [1]);
      expect(snap.textOf(0), isNull);
      expect(snap.hasHeard(1), isFalse);
      expect(snap.heardOf(1), isNull);
    });

    test('kata merah di ayat lain tetap menyimpan bunyinya', () {
      final snap = AsrSnapshot()
        ..recordHeard(1, 'XX')
        ..recordHeard(9, 'YY');
      snap.rewind(forgetWords: [1]);
      expect(snap.hasHeard(1), isFalse);
      expect(snap.heardOf(9), 'YY');
    });

    test('snapshot epoch lama tidak dipakai percobaan berikutnya', () {
      final snap = AsrSnapshot()..keep(0, 'اا');
      snap.rewind();
      expect(snap.textOf(0), isNull);
      snap.keep(0, 'ب');
      expect(snap.textOf(0), 'ب');
    });
  });

  group('displayHeard: teks tampilan', () {
    test('penanda madd jadi huruf mad, tanpa ء dan tanpa pemisah', () {
      final shown = displayHeard('ررَحِۦۦۦۦم');
      expect(shown.contains('\u0621'), isFalse);
      expect(shown.contains('\u06E6'), isFalse);
      expect(shown.contains('\u200C'), isFalse);
      expect(shown.contains(' '), isFalse);
      expect(shown, 'رَحِيم');
    });

    test('kasrah/fathah/dammah memilih huruf mad yang benar', () {
      expect(displayHeard('\u0628\u0650\u06E6\u0645'), contains('\u064A'));
      expect(displayHeard('\u0628\u064E\u0670\u0645'), contains('\u0627'));
      expect(displayHeard('\u0628\u064F\u06E5\u0645'), contains('\u0648'));
    });

    test('penanda madd tanpa harakat dibuang', () {
      expect(displayHeard('\u0628\u06E6\u0645'), 'بم');
    });

    test('pemisah token dan karakter kendali dibuang', () {
      expect(displayHeard('▁ر ح\u200Cي ▁م'), 'رحي م'.replaceAll(' ', ''));
      expect(displayHeard('  <blank>  '), '');
    });

    test('harakat dipertahankan, huruf berulang diringkas', () {
      expect(displayHeard('ررَّحِيم'), 'رَّحِيم');
    });
  });

  group('isWrongReading: hijau palsu', () {    // Fonem asli Al-Fatihah (matcher: skor 0.857 → tetap hijau).
    test('mim → nun pada kata panjang = salah baca', () {
      expect(
        isWrongReading('ررَحِۦۦۦۦم', 'ررَحِۦۦۦۦن'),
        isTrue,
      );
    });

    test('bacaan benar = bukan salah baca', () {
      expect(isWrongReading('ررَحِۦۦۦۦم', 'ررَحِۦۦۦۦم'), isFalse);
    });

    test('madd diulang/diringkas ASR bukan salah baca', () {
      expect(isWrongReading('ررَحمَاانِ', 'ررَحمَانِ'), isFalse);
    });

    test('harakat berbeda bukan salah baca (model tidak andal)', () {
      expect(isWrongReading('بِسمِ', 'بِسمَ'), isFalse);
    });

    test('huruf akustik mirip (ص→س) bukan salah baca', () {
      expect(isWrongReading('صصِرَااطَ', 'سِرَااطَ'), isFalse);
    });

    test('slot memuat kata berikutnya = tidak diputuskan', () {
      expect(isWrongReading('ررَحِۦۦۦۦم', 'كَتَبَررَحِۦۦۦۦم'), isFalse);
    });

    test('slot kosong = tidak diputuskan', () {
      expect(isWrongReading('بِسمِ', null), isFalse);
      expect(isWrongReading('بِسمِ', ''), isFalse);
    });
  });
}

List<int> _boundaries(List<String> words) {
  final bounds = <int>[0];
  var offset = 0;
  for (final w in words) {
    offset += w.length;
    bounds.add(offset);
  }
  return bounds;
}
