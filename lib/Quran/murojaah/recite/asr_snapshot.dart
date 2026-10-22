/// Transkrip ASR yang disimpan untuk sheet koreksi.
///
/// Dua hal yang harus dijaga:
///
/// 1. Transkrip bersifat **kumulatif per segmen**, jadi versi terpanjang adalah
///    versi paling lengkap — hasil parsial yang lebih pendek tidak menimpanya.
/// 2. Snapshot terikat ke satu percobaan ([epoch]). Setelah Ulangi/Reset kursor
///    tracker mundur dan mikrofon menyala lagi; snapshot percobaan sebelumnya
///    sudah tidak menggambarkan bacaan sekarang dan tidak boleh dipakai.
class AsrSnapshot {
  int _epoch = 0;
  final Map<int, String> _byVerse = {};
  final Map<int, int> _epochOf = {};
  final Map<int, String?> _heard = {};

  /// Nomor percobaan berjalan.
  int get epoch => _epoch;

  /// Simpan transkrip [text] untuk [verse] bila lebih lengkap dari yang ada.
  void keep(int verse, String text) {
    if (text.trim().isEmpty) return;
    if (_epochOf[verse] != _epoch) {
      _byVerse[verse] = text;
      _epochOf[verse] = _epoch;
      return;
    }
    if (text.length >= (_byVerse[verse]?.length ?? 0)) _byVerse[verse] = text;
  }

  /// Transkrip percobaan ini untuk [verse]; null bila belum ada atau epoch lama.
  String? textOf(int verse) =>
      _epochOf[verse] == _epoch ? _byVerse[verse] : null;

  /// Bunyi yang menempati slot [wordId] **pada saat** kata itu dinilai merah.
  ///
  /// Disimpan supaya sheet koreksi tidak menghitung ulang dari transkrip
  /// terbaru — transkrip terus bertambah dan bisa sudah memuat kata berikutnya.
  void recordHeard(int wordId, String? heard) => _heard[wordId] = heard;

  bool hasHeard(int wordId) => _heard.containsKey(wordId);
  String? heardOf(int wordId) => _heard[wordId];

  void forgetHeard(Iterable<int> wordIds) {
    for (final id in wordIds) {
      _heard.remove(id);
    }
  }

  /// Percobaan baru: semua snapshot ayat tidak berlaku lagi.
  ///
  /// [forgetWords] kata yang penilaiannya ikut dibatalkan (mis. satu ayat saat
  /// Ulangi); kata merah di ayat lain tetap menyimpan bunyinya.
  void rewind({Iterable<int> forgetWords = const []}) {
    _epoch++;
    _byVerse.clear();
    _epochOf.clear();
    forgetHeard(forgetWords);
  }
}
