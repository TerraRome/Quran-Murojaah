import 'dart:math';

/// Potongan transkrip ASR yang menempati slot sebuah kata, atau null bila
/// memang tidak ada suara di posisi itu.
///
/// `recite_quran` melaporkan kata yang **salah dibaca** dan kata yang
/// **dilewati** dengan bentuk yang sama: `WordMatchedEvent(isRed: true,
/// cleanAsr: '')` — `DictationSequencer._commitRed` selalu mengirim `cleanAsr`
/// kosong dan hanya mengisi `cleanAsr` untuk event hijau. Bedanya hanya terlihat
/// di transkrip: pada substitusi ada bunyi pengganti di antara kata sebelumnya
/// dan kata berikutnya; pada kata yang dilewati transkrip langsung melompat.
///
/// Slot kata direkonstruksi dari transkrip ayat: LCS fonem ↔ ASR diselaraskan
/// sekali untuk seluruh ayat, lalu tiap kata mendapat rentang bersambung yang
/// tidak tumpang tindih (lihat [wordAsrRanges]). Rentang itu adalah **seluruh**
/// bunyi yang mengisi slot — termasuk huruf yang salah diucapkan, yang justru
/// tidak ikut sejajar dengan acuan.
///
/// [phonemesPerWord] fonem kata-kata **satu ayat**, [wordIndex] indeks lokal
/// kata di ayat itu, [emitted] transkrip fonetis ASR.
String? heardForWord({
  required List<String> phonemesPerWord,
  required int wordIndex,
  required String emitted,
}) {
  if (wordIndex < 0 || wordIndex >= phonemesPerWord.length) return null;
  final asr = emitted.trim();
  if (asr.isEmpty) return null;

  final (start, end) = wordAsrRanges(
    phonemesPerWord: phonemesPerWord,
    emitted: asr,
  )[wordIndex];

  if (end <= start) return null;
  final heard = asr.substring(start, end).trim();
  if (heard.isEmpty) return null;
  // Sisa harakat/madd tanpa huruf bukan bunyi kata: jangan tampilkan sebagai
  // "terdengar", dan jangan dipakai memutuskan salah baca.
  return consonantSkeleton(heard).isEmpty ? null : heard;
}

/// Rentang ASR (indeks karakter pada [emitted] yang sudah di-trim) untuk tiap
/// kata satu ayat.
///
/// LCS fonem ↔ transkrip diselaraskan **sekali** untuk seluruh ayat, lalu batas
/// antar kata diambil dari posisi fonem pertama kata berikutnya yang benar-benar
/// cocok. Hasilnya bersambung dan **tidak tumpang tindih**: kata N tidak bisa
/// memakai bunyi milik kata N-1 atau N+1 walau ada huruf kembar (`ال` yang
/// menyatu ke kata berikutnya, `ررَ` ganda).
///
/// Kata yang sama sekali tidak cocok tetap mendapat rentang — bunyi penggantinya
/// ada di antara dua jangkar — sehingga substitusi bisa dibedakan dari kata yang
/// dilewati (rentang kosong).
///
/// Kata pertama juga otomatis memotong awalan transkrip yang berasal dari ayat
/// sebelumnya (transkrip ASR kumulatif per segmen).
List<(int, int)> wordAsrRanges({
  required List<String> phonemesPerWord,
  required String emitted,
}) {
  final k = phonemesPerWord.length;
  final ranges = List<(int, int)>.filled(k, (0, 0));
  final asr = emitted.trim();
  final ref = phonemesPerWord.join();
  if (k == 0 || asr.isEmpty || ref.isEmpty) return ranges;

  // Offset fonem tiap kata di dalam `ref`.
  final starts = List<int>.filled(k, 0);
  for (var i = 1; i < k; i++) {
    starts[i] = starts[i - 1] + phonemesPerWord[i - 1].length;
  }

  // Kata → indeks ASR fonem pertama & terakhir yang cocok.
  final firstMapped = List<int?>.filled(k, null);
  final lastMapped = List<int?>.filled(k, null);
  _lcsMap(ref, asr).forEach((refIndex, asrIndex) {
    final word = _wordAt(starts, refIndex);
    firstMapped[word] ??= asrIndex;
    lastMapped[word] = asrIndex;
  });

  var boundary = 0;
  for (var w = 0; w < k; w++) {
    final anchor = firstMapped[w];
    final start = anchor == null ? boundary : max(boundary, anchor);

    // Kata berikutnya yang punya jangkar menentukan akhir rentang.
    var nextAnchor = -1;
    for (var j = w + 1; j < k; j++) {
      if (firstMapped[j] != null) {
        nextAnchor = j;
        break;
      }
    }

    int end;
    if (w == k - 1) {
      // Sisa transkrip setelah jangkar terakhir milik kata terakhir.
      end = asr.length;
    } else if (nextAnchor == w + 1) {
      // Kata sesudahnya cocok: sisipan sebelum huruf pertamanya milik kata ini
      // (huruf yang salah diucapkan di ekor kata).
      end = firstMapped[w + 1]!;
    } else {
      // Ada kata tanpa jangkar di antara: bunyi sisipan itu milik kata yang
      // tidak cocok, bukan milik kata ini.
      final last = lastMapped[w];
      end = last == null ? boundary : last + 1;
    }
    if (end < start) end = start;
    ranges[w] = (start, end);
    boundary = end;
  }
  return ranges;
}

/// Jumlah karakter awal [emitted] yang sudah dipakai kata-kata
/// [phonemesPerWord].
///
/// Transkrip ASR bersifat kumulatif per segmen: saat pelacakan pindah ke ayat
/// berikutnya, transkrip masih memuat bunyi ayat sebelumnya. Angka ini dipakai
/// sebagai offset supaya slot kata ayat baru tidak mengambil bunyi ayat lama.
int asrConsumed({
  required List<String> phonemesPerWord,
  required String emitted,
}) {
  final asr = emitted.trim();
  final ref = phonemesPerWord.join();
  if (asr.isEmpty || ref.isEmpty) return 0;
  var consumed = 0;
  for (final asrIndex in _lcsMap(ref, asr).values) {
    if (asrIndex + 1 > consumed) consumed = asrIndex + 1;
  }
  return consumed;
}

/// Indeks kata pemilik fonem ke-[refIndex].
int _wordAt(List<int> starts, int refIndex) {
  var lo = 0;
  var hi = starts.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) ~/ 2;
    if (starts[mid] <= refIndex) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo;
}

/// Jejak LCS [ref] ↔ [asr]: peta refIndex → asrIndex.
Map<int, int> _lcsMap(String ref, String asr) {
  final n = ref.length;
  final m = asr.length;
  final mapped = <int, int>{};
  if (n == 0 || m == 0) return mapped;

  // lcs[i][j] = panjang LCS ref[i..] vs asr[j..].
  final lcs = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      lcs[i][j] = ref.codeUnitAt(i) == asr.codeUnitAt(j)
          ? lcs[i + 1][j + 1] + 1
          : max(lcs[i + 1][j], lcs[i][j + 1]);
    }
  }

  // refIndex → asrIndex hasil jejak LCS.
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    // Bila melewati fonem ini tidak mengurangi LCS, lewati: huruf yang sama
    // lebih baik dipakai kata berikutnya. Tanpa ini, kata yang dilewati bisa
    // "mencuri" huruf dari kata sesudahnya (الله vs الرحمن) dan tampak
    // terdengar padahal tidak diucapkan.
    if (ref.codeUnitAt(i) == asr.codeUnitAt(j) && lcs[i + 1][j] < lcs[i][j]) {
      mapped[i] = j;
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  return mapped;
}

/// Kerangka konsonan kata: harakat, tanwin, sukun, shaddah, madd marker, dan
/// tanda baca sakt/ishmam dibuang; huruf berulang (shaddah/madd) diringkas;
/// pasangan huruf yang secara akustik memang tertukar disamakan.
///
/// Dipakai untuk memutuskan apakah kata yang dilaporkan **hijau** oleh matcher
/// benar-benar diucapkan. `recite_quran` menormalkan biaya salah baca per
/// panjang kata acuan, sehingga satu fonem salah pada kata panjang tetap lolos
/// ambang (mis. `…م` → `…ن` skor 0.857 masih hijau). Perbandingan kerangka
/// menutup celah itu tanpa memerahkan bacaan benar.
///
/// ponytail: harakat tidak dibandingkan — model CTC tidak cukup andal pada
/// vokal pendek, dan `acousticConfusionCost` bawaan sudah menyamakan sebagian
/// harakat. Naikkan ke perbandingan penuh bila akurasi harakat terbukti stabil.
String consonantSkeleton(String phonemes) {
  final out = <int>[];
  for (final code in phonemes.codeUnits) {
    final isHaraka = code >= 0x064B && code <= 0x0655;
    final isMarker = code == 0x0670 || // ٰ
        code == 0x06E5 || // ۥ small waw
        code == 0x06E6 || // ۦ small yaa
        code == 0x0686 || // ڇ qalqalah burst
        code == 0x06DC || // ۜ sakt
        code == 0x0619 || // ؙ ishmam
        code == 0x06EA || // ۪ imalah
        code == 0x0640; // ـ tatweel
    if (isHaraka || isMarker) continue;
    final canonical = _canonicalConsonant(code);
    if (out.isNotEmpty && out.last == canonical) continue;
    out.add(canonical);
  }
  return String.fromCharCodes(out);
}

/// Huruf yang oleh `PhoneticCostEngine.isEquivalentGlyph` /
/// `_isAcousticConfusion` dianggap bunyi yang sama. Menyamakannya di sini
/// mencegah bacaan benar (mis. صراط diucapkan dengan س) tampil sebagai salah.
int _canonicalConsonant(int code) {
  return switch (code) {
    0x0637 => 0x062A, // ط → ت
    0x0632 || 0x0630 || 0x0638 => 0x062C, // ز ذ ظ → ج
    0x063A => 0x062E, // غ → خ
    0x0636 => 0x062F, // ض → د
    0x0635 => 0x0633, // ص → س
    0x0643 => 0x0642, // ك → ق
    0x0647 || 0x0629 => 0x062A, // ه ة → ت
    0x06FE => 0x0645, // ۾ → م
    0x06BA => 0x0646, // ں → ن
    0x0622 || 0x0623 || 0x0625 || 0x0672 => 0x0621, // varian hamza
    _ => code,
  };
}

/// Teks tampilan untuk potongan transkrip ASR.
///
/// Transkrip mentah adalah deret **fonem**, bukan kata: harakat, penanda madd
/// (`ۥ` `ۦ` `ٰ`), huruf berulang, dan sisa pemisah token. Penanda madd tidak
/// punya bentuk sambung sehingga dirender sebagai potongan terpisah (tampak
/// seperti `ء`) dan memutus shaping Arab. Fungsi ini merapikannya **untuk
/// tampilan saja** — data yang dipakai matcher dan [isWrongReading] tidak
/// diubah.
///
/// - Semua karakter di luar blok Arab (spasi, ZWNJ/ZWJ, `▁`, `<blank>`, `|`)
///   dibuang.
/// - Penanda madd diganti huruf mad sesuai harakat sebelumnya: kasrah → `ي`,
///   fathah → `ا`, dammah → `و`. Tanpa harakat → dibuang.
/// - Huruf mad dan harakat berulang diringkas.
String displayHeard(String raw) {
  final out = <int>[];
  var haraka = 0;
  for (final code in raw.codeUnits) {
    // Di luar blok Arab: pemisah token, spasi, ZWNJ/ZWJ, sisa ASCII.
    if (code < 0x0600) {
      haraka = 0;
      continue;
    }
    if (_isDroppedForDisplay(code)) {
      if (code != 0x0640) haraka = 0;
      continue;
    }
    if (code >= 0x064B && code <= 0x0652) {
      haraka = code;
      if (out.isEmpty || out.last != code) out.add(code);
      continue;
    }
    if (_isMaddMarker(code)) {
      // Tanpa harakat sebelumnya tidak ada huruf mad yang bisa dipilih.
      final madd = _maddLetterFor(code, haraka);
      if (madd != null && (out.isEmpty || out.last != madd)) out.add(madd);
      continue;
    }
    // Huruf berulang (shaddah/madd ganda) tidak menambah informasi visual.
    if (out.isNotEmpty && out.last == code) continue;
    haraka = 0;
    out.add(code);
  }
  return String.fromCharCodes(out).trim();
}

/// Penanda yang tidak boleh ikut dirender: tanpa bentuk sambung atau tidak
/// informatif untuk pengguna.
bool _isDroppedForDisplay(int code) => switch (code) {
      0x0640 || // ـ tatweel
      0x0686 || // ڇ qalqalah burst
      0x06DC || // ۜ sakt
      0x0619 || // ؙ ishmam
      0x06EA || // ۪ imalah
      0x200C ||
      0x200D ||
      0x200E ||
      0x200F ||
      0x2581 =>
        true,
      _ => false,
    };

/// Penanda madd: `ٰ` superscript alef, `ۥ` small waw, `ۦ` small yaa, `ٓ` madda.
bool _isMaddMarker(int code) =>
    code == 0x0670 || code == 0x06E5 || code == 0x06E6 || code == 0x0653;

/// Huruf mad pengganti penanda madd, atau null bila penanda ini dibuang.
int? _maddLetterFor(int code, int haraka) {
  if (!_isMaddMarker(code)) return null;
  return switch (haraka) {
    0x0650 => 0x064A, // kasrah → ي
    0x064E || 0x064B => 0x0627, // fathah/fathatan → ا
    0x064F || 0x064C => 0x0648, // dammah/dammatan → و
    _ => null,
  };
}

/// Apakah [heard] (slot ASR untuk satu kata) berbeda huruf dari [expected]?
///
/// Hanya memutuskan bila panjangnya sebanding dan kerangkanya sama panjang:
/// slot yang lebih panjang berarti transkrip sudah memuat kata berikutnya, dan
/// kerangka yang lebih pendek berarti ASR menghilangkan huruf — keduanya bukan
/// bukti salah baca.
bool isWrongReading(String expected, String? heard) {
  if (heard == null || heard.isEmpty || expected.isEmpty) return false;
  if (heard.length > expected.length + 2) return false;
  if (heard.length + 2 < expected.length) return false;
  final want = consonantSkeleton(expected);
  final got = consonantSkeleton(heard);
  if (want.length != got.length) return false;
  return want != got;
}
