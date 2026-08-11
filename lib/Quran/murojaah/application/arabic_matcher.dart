/// Hasil matching bacaan — sesuai MUROJAAH_RULES section 12.
enum MatchResult {
  /// Bacaan benar — skor >= [ArabicMatcher.acceptThreshold].
  accept,

  /// Hampir benar — skor >= [ArabicMatcher.almostThreshold] tapi < accept.
  almost,

  /// Bacaan salah — skor di bawah [ArabicMatcher.almostThreshold].
  reject,
}

/// Normalisasi & pencocokan teks Arab/Latin untuk murojaah.
///
/// Mengimplementasikan tiga pipeline sesuai MUROJAAH_RULES:
/// - Pipeline A: [normalizeArabic] — Arabic STT matching
/// - Pipeline B: [normalizeLatin] — Latin STT matching (transliteration)
/// - Pipeline C: [matchArabic] / [matchLatin] — MatchResult dengan score
///
/// Transkrip STT (tanpa harakat, variasi huruf أ/إ/آ/ى/ة) dibandingkan dengan
/// teks ayat dari aset (Uthmani penuh harakat). Murni Dart, tanpa framework.
class ArabicMatcher {
  const ArabicMatcher._();

  // ─── Threshold ────────────────────────────────────────────────────────────

  /// Skor minimum untuk ACCEPT (>= 90% kata cocok berurutan).
  static const double acceptThreshold = 0.90;

  /// Skor minimum untuk ALMOST (>= 75% kata cocok berurutan).
  static const double almostThreshold = 0.75;

  /// Alias untuk kompatibilitas mundur — sama dengan [acceptThreshold].
  static const double defaultThreshold = acceptThreshold;

  // ─── Regex ────────────────────────────────────────────────────────────────

  static final RegExp _diacritics = RegExp(
    r'[\u064B-\u065F\u0670\u06D6-\u06ED\u08D3-\u08FF]',
  );

  // ─── Muqatta'at maps ──────────────────────────────────────────────────────

  /// Mapping huruf muqatta'at (teks Uthmani tanpa harakat) ke bentuk
  /// pelafalan yang dinormalisasi untuk STT matching. Kunci adalah teks
  /// setelah strip diacritic dan strip tanda mad (ٓ U+0653). Nilai adalah
  /// pelafalan per huruf dipisah spasi, sudah dalam bentuk normalize().
  ///
  /// Referensi pelafalan standar qira'at Hafs 'an 'Asim.
  static const Map<String, String> _muqattaat = {
    'الم': 'الف لام ميم',
    'المص': 'الف لام ميم صاد',
    'الر': 'الف لام را',
    'المر': 'الف لام ميم را',
    'كهيعص': 'كاف ها يا عين صاد',
    'طه': 'طا ها',
    'طسم': 'طا سين ميم',
    'طس': 'طا سين',
    'يس': 'يا سين',
    'ص': 'صاد',
    'حم': 'حا ميم',
    'عسق': 'عين سين قاف',
    'ق': 'قاف',
    'ن': 'نون',
  };

  /// Mapping muqatta'at ke pelafalan berharakat penuh untuk TTS.
  ///
  /// Berbeda dari [_muqattaat] yang untuk STT matching (tanpa harakat),
  /// map ini menyertakan harakat mad agar TTS ar-SA membaca panjang-pendek
  /// dengan benar sesuai tajwid. Contoh: يس dibaca "yaaaaa siiin" bukan "yasin".
  static const Map<String, String> _muqattaatTts = {
    'الم': 'أَلِفْ لَامْ مِيمْ',
    'المص': 'أَلِفْ لَامْ مِيمْ صَادْ',
    'الر': 'أَلِفْ لَامْ رَا',
    'المر': 'أَلِفْ لَامْ مِيمْ رَا',
    'كهيعص': 'كَافْ هَا يَا عَيْنْ صَادْ',
    'طه': 'طَا هَا',
    'طسم': 'طَا سِيْنْ مِيمْ',
    'طس': 'طَا سِيْنْ',
    'يس': 'يَاسِيْنْ',
    'ص': 'صَادْ',
    'حم': 'حَا مِيمْ',
    'عسق': 'عَيْنْ سِيْنْ قَافْ',
    'ق': 'قَافْ',
    'ن': 'نُوْنْ',
  };

  /// Alias STT: bentuk yang sering dihasilkan recognizer Arab saat membaca
  /// huruf muqatta'at sebagai satu kata gabungan. Di-map ke bentuk normalize()
  /// yang sudah di-expand sehingga matching tetap berhasil.
  static const Map<String, String> _sttAliases = {
    'ياسين': 'يا سين',
    'الم': 'الف لام ميم',
    'طاها': 'طا ها',
    'حاميم': 'حا ميم',
  };

  // ─── Pipeline A: Arabic normalization ─────────────────────────────────────

  /// Buang semua diakritik (harakat, tanda sukun, dst.) dan tanda Al-Quran
  /// tambahan, lalu normalisasi varian huruf ke bentuk dasar.
  /// Huruf muqatta'at otomatis di-expand ke pelafalan penuh.
  /// Alias STT (bentuk gabungan seperti "ياسين") juga di-expand.
  ///
  /// Alias [normalize] untuk kompatibilitas mundur.
  static String normalizeArabic(String input) {
    var s = input;
    s = s.replaceAll('\u0670', '\u0627'); // superscript alif ٰ → ا (expand sebelum strip diacritics)
    s = s.replaceAll(_diacritics, '');
    s = s.replaceAll('\u0653', ''); // mad ٓ
    s = s.replaceAll('\u0640', ''); // tatweel ـ
    s = s.replaceAll('\u0622', '\u0627'); // آ → ا
    s = s.replaceAll('\u0623', '\u0627'); // أ → ا
    s = s.replaceAll('\u0625', '\u0627'); // إ → ا
    s = s.replaceAll('\u0671', '\u0627'); // ٱ (alef wasla) → ا
    s = s.replaceAll('\u0629', '\u0647'); // ة → ه
    s = s.replaceAll('\u0649', '\u064A'); // ى → ي
    s = s.replaceAll('\u0626', '\u064A'); // ئ → ي
    s = s.replaceAll('\u0624', '\u0648'); // ؤ → و
    s = s.replaceAll('\u0621', ''); // ء dibuang
    s = s.replaceAll(
      RegExp(r'\u0628\u0627\u0633\u0645'),
      '\u0628\u0633\u0645',
    ); // باسم → بسم
    final words = s.trim().split(RegExp(r'\s+'));
    final expanded = words
        .map((w) => _sttAliases[w] ?? _muqattaat[w] ?? w)
        .join(' ');
    return expanded.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Alias untuk [normalizeArabic] — kompatibilitas mundur.
  static String normalize(String input) => normalizeArabic(input);

  // ─── Pipeline B: Latin normalization ──────────────────────────────────────

  /// Normalisasi teks Latin (transliteration) untuk matching mesin.
  ///
  /// Sesuai MUROJAAH_RULES section 7 & 8:
  /// - Lowercase
  /// - Strip notasi waqf/wasl: (a), (i), (u)
  /// - Diacritic Latin → ASCII: ā→a, ī→i, ū→u, ḥ→h, ṣ→s, ṭ→t, ẓ→z, ḍ→d
  /// - Strip tanda apostrof dan hamzah: ʿ, ʾ, '
  /// - Hyphen & dash → spasi (section 8)
  /// - Strip tanda baca: . , ; : ! ? " ' « »
  /// - Normalisasi spasi ganda
  ///
  /// Contoh: "Wal-qur'ānil-ḥakīm(i)." → "wal quranilhakim"
  static String normalizeLatin(String latin) {
    var s = latin.toLowerCase();
    // Strip notasi waqf/wasl seperti (a), (i), (u) — MUROJAAH_RULES section 4
    s = s.replaceAll(RegExp(r'\([aiu]\)'), '');
    // Diacritic Latin → ASCII — MUROJAAH_RULES section 7
    s = s.replaceAll('ā', 'a').replaceAll('ī', 'i').replaceAll('ū', 'u');
    s = s.replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('ó', 'o');
    s = s.replaceAll('ḥ', 'h').replaceAll('ṣ', 's').replaceAll('ṭ', 't');
    s = s.replaceAll('ẓ', 'z').replaceAll('ḍ', 'd').replaceAll('ġ', 'g');
    s = s.replaceAll('ż', 'z');   // U+017C dzal (ذ)
    s = s.replaceAll('ṡ', 's');   // U+1E61 tsa (ث)
    s = s.replaceAll('ʿ', '').replaceAll('ʾ', '').replaceAll("'", '');
    // Apostrof tipografi & tanda lain
    s = s.replaceAll('\u2018', '').replaceAll('\u2019', ''); // ' '
    s = s.replaceAll('\u2026', ''); // … ellipsis
    // Hyphen & dash → spasi — MUROJAAH_RULES section 8
    s = s.replaceAll(RegExp(r'[-\u2013\u2014]'), ' ');
    // Strip tanda baca
    s = s.replaceAll(
        RegExp(r'[.,;:!?"""''\u2018\u2019\u201C\u201D\u00AB\u00BB]'), '');
    // Normalisasi spasi
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  // ─── Pipeline C: MatchResult ───────────────────────────────────────────────

  /// Hitung skor matching antara [expectedWords] dan [transcriptWords].
  ///
  /// Skor = jumlah kata expected yang ditemukan berurutan dalam transcript
  /// dibagi total kata expected. Kata tambahan di transcript tidak mengurangi skor.
  static double _score(List<String> expectedWords, List<String> transcriptWords,
      {required bool isArabic}) {
    if (expectedWords.isEmpty || transcriptWords.isEmpty) return 0.0;
    if (expectedWords.length == 1) {
      final found = isArabic
          ? transcriptWords.any((w) => _wordEquals(expectedWords[0], w))
          : transcriptWords
              .any((w) => _latinWordEquals(expectedWords[0], w));
      return found ? 1.0 : 0.0;
    }
    var matched = 0;
    var searchFrom = 0;
    for (final word in expectedWords) {
      final found = isArabic
          ? _indexOfFrom(transcriptWords, word, searchFrom)
          : _indexOfFromLatin(transcriptWords, word, searchFrom);
      if (found == -1) continue;
      matched++;
      searchFrom = found + 1;
    }
    return matched / expectedWords.length;
  }

  /// MatchResult untuk Arabic matching.
  ///
  /// [expected] — teks Arab ayat (dengan harakat).
  /// [transcript] — transkrip STT (Arab atau campuran).
  /// [surahNumber] — bila disediakan, strip basmala prefix untuk surah ≠ 1.
  static MatchResult matchArabic({
    required String expected,
    required String transcript,
    double accept = acceptThreshold,
    double almost = almostThreshold,
    int? surahNumber,
  }) {
    final score = scoreArabic(
      expected: expected,
      transcript: transcript,
      surahNumber: surahNumber,
    );
    if (score >= accept) return MatchResult.accept;
    if (score >= almost) return MatchResult.almost;
    return MatchResult.reject;
  }

  /// Skor numerik Arabic matching (0.0–1.0). Berguna untuk debugging.
  static double scoreArabic({
    required String expected,
    required String transcript,
    int? surahNumber,
  }) {
    var effectiveExpected = expected;
    if (surahNumber != null && surahNumber != 1) {
      final trimmed = expected.trimLeft();
      if (trimmed.startsWith(_basmalaPrefix)) {
        effectiveExpected = trimmed.substring(_basmalaPrefix.length).trimLeft();
      }
    }
    final expectedWords = normalizeArabic(effectiveExpected).split(' ');
    final transcriptWords = normalizeArabic(transcript).split(' ');
    return _score(expectedWords, transcriptWords, isArabic: true);
  }

  /// MatchResult untuk Latin matching (transliteration).
  ///
  /// [verseNormalized] — [Verse.normalizedText] pre-computed.
  /// [transcript] — transkrip STT dalam Latin.
  static MatchResult matchLatin({
    required String verseNormalized,
    required String transcript,
    double accept = acceptThreshold,
    double almost = almostThreshold,
  }) {
    final score = scoreLatin(
      verseNormalized: verseNormalized,
      transcript: transcript,
    );
    if (score >= accept) return MatchResult.accept;
    if (score >= almost) return MatchResult.almost;
    return MatchResult.reject;
  }

  /// Skor numerik Latin matching (0.0–1.0). Berguna untuk debugging.
  static double scoreLatin({
    required String verseNormalized,
    required String transcript,
  }) {
    if (verseNormalized.isEmpty) return 0.0;
    final expectedWords = verseNormalized.split(' ');
    final transcriptWords = normalizeLatin(transcript).split(' ');
    return _score(expectedWords, transcriptWords, isArabic: false);
  }

  /// Kompatibilitas mundur: kembalikan bool dari Arabic matching.
  static bool isCorrect({
    required String expected,
    required String transcript,
    double threshold = defaultThreshold,
    int? surahNumber,
  }) {
    return scoreArabic(
          expected: expected,
          transcript: transcript,
          surahNumber: surahNumber,
        ) >=
        threshold;
  }

  // ─── TTS helpers ──────────────────────────────────────────────────────────

  /// Teks Arab yang sudah di-expand muqatta'at-nya untuk keperluan TTS.
  static String expandForTts(String arabic) {
    var s = arabic.replaceAll(_diacritics, '').replaceAll('\u0653', '');
    s = s.replaceAll('\u0640', '');
    final words = arabic.trim().split(RegExp(r'\s+'));
    final strippedWords = s.trim().split(RegExp(r'\s+'));
    final result = <String>[];
    for (var i = 0; i < words.length; i++) {
      final stripped = i < strippedWords.length ? strippedWords[i] : '';
      result.add(_muqattaatTts[stripped] ?? words[i]);
    }
    return applyWaqf(result.join(' '));
  }

  /// Terapkan waqf: beri sukun (ْ U+0652) pada huruf konsonan terakhir ayat.
  static String applyWaqf(String arabic) {
    if (arabic.isEmpty) return arabic;
    final trimmed = arabic.trimRight();
    if (trimmed.isEmpty) return arabic;

    const removableEnd = {
      '\u064E', // fathah
      '\u064F', // dammah
      '\u0650', // kasrah
      '\u064B', // fathatan
      '\u064C', // dammatan
      '\u064D', // kasratan
    };

    const madLetters = {
      '\u0627', // alif
      '\u0648', // waw
      '\u064A', // ya
      '\u0649', // alif maqsura
    };

    var s = trimmed;

    bool isRemovable(String c) {
      if (removableEnd.contains(c)) return true;
      final cp = c.codeUnitAt(0);
      return cp >= 0x06D6 && cp <= 0x06ED;
    }

    while (s.isNotEmpty && isRemovable(s[s.length - 1])) {
      s = s.substring(0, s.length - 1);
    }

    if (s.isEmpty) return arabic;
    final lastChar = s[s.length - 1];
    if (lastChar == '\u0652' || madLetters.contains(lastChar)) return s;
    return '$s\u0652';
  }

  // ─── Internal helpers ─────────────────────────────────────────────────────

  static const String _basmalaPrefix =
      'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  static int _indexOfFrom(List<String> words, String target, int from) {
    for (var i = from; i < words.length; i++) {
      if (_wordEquals(words[i], target)) return i;
    }
    return -1;
  }

  static int _indexOfFromLatin(List<String> words, String target, int from) {
    for (var i = from; i < words.length; i++) {
      if (_latinWordEquals(words[i], target)) return i;
    }
    return -1;
  }

  /// Dua kata Arab dianggap sama bila identik, atau berjarak edit 1 untuk
  /// kata yang cukup panjang. Kata ≤2 huruf wajib sama persis.
  static bool _wordEquals(String a, String b) {
    if (a == b) return true;
    if (a.length < 3 || b.length < 3) return false;
    return _levenshtein(a, b) <= 1;
  }

  /// Dua kata Latin dianggap sama bila identik, atau berjarak edit ≤1 untuk
  /// kata ≥4 karakter (toleransi typo/variasi transliterasi).
  static bool _latinWordEquals(String a, String b) {
    if (a == b) return true;
    if (a.length < 4 || b.length < 4) return false;
    return _levenshtein(a, b) <= 1;
  }

  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current[j] = [
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      previous = current;
    }
    return previous[b.length];
  }
}
