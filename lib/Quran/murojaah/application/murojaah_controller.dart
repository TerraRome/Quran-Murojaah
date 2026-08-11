import 'package:flutter/foundation.dart';

import '../domain/murojaah_matcher.dart';
import 'arabic_matcher.dart';

/// Status siklus murojaah.
enum MurojaahStatus { idle, listening, validating, revealed, error }

/// Status eksekusi fitur murojaah.
enum MurojaahPhase { initial, running, completed }

/// State sederhana module Murojaah (ValueNotifier, tanpa Bloc),
/// mengikuti pola QuranController pada module Quran.
///
/// Logika matching dijalankan di controller — page hanya observe state
/// dan trigger action, sesuai MUROJAAH_RULES section 18.
class MurojaahController extends ValueNotifier<MurojaahState> {
  MurojaahController() : super(const MurojaahState.initial());

  /// Kumpulan ayats (indeks 0-based) yang telah ter-reveal.
  final Set<int> _revealed = {};

  /// Jumlah validasi salah beruntun pada ayat aktif. Setelah
  /// [helpThreshold] kali salah, halaman memicu bantuan (TTS membacakan
  /// ayat yang benar; user tetap bisa mencoba lagi).
  int _incorrectAttempts = 0;

  /// Akumulasi transkrip STT untuk ayat aktif.
  ///
  /// Pada ayat panjang user bisa rekam beberapa kali — setiap potongan
  /// transkrip digabungkan di sini dengan spasi. Divalidasi saat STT
  /// selesai otomatis atau saat user menekan tombol "Selesai".
  /// Direset otomatis saat ayat benar (maju ke ayat berikutnya) atau ulang.
  String _accumulatedTranscript = '';

  /// Batas jumlah kata ayat untuk dianggap "ayat panjang" — menampilkan
  /// tombol "Selesai" agar user bisa rekam beberapa kali (multi-rekam).
  static const int longVerseWordThreshold = 15;

  /// Batas percobaan salah sebelum bantuan bacaan dipicu.
  static const int helpThreshold = 3;

  // ─── Getters ──────────────────────────────────────────────────────────────

  /// Apakah ayat pada `index` (0-based) sudah ter-reveal.
  bool isRevealed(int index) => _revealed.contains(index);

  int get revealedCount => _revealed.length;

  /// Transkrip STT yang sudah terakumulasi untuk ayat aktif.
  String get accumulatedTranscript => _accumulatedTranscript;

  /// Apakah ada transkrip yang sudah terakumulasi.
  bool get hasAccumulated => _accumulatedTranscript.trim().isNotEmpty;

  /// Jumlah percobaan salah beruntun pada ayat aktif saat ini.
  int get incorrectAttempts => _incorrectAttempts;

  /// `true` bila sudah [helpThreshold] kali salah beruntun.
  bool get needsHelp => _incorrectAttempts >= helpThreshold;

  /// `true` pada percobaan salah ke-[helpThreshold] dan setiap kelipatannya.
  bool get shouldTriggerHelp =>
      _incorrectAttempts != 0 && _incorrectAttempts % helpThreshold == 0;

  /// Apakah ayat dengan [wordCount] kata termasuk ayat panjang.
  static bool isLongVerse(int wordCount) => wordCount >= longVerseWordThreshold;

  // ─── Transcript accumulation ──────────────────────────────────────────────

  /// Tambahkan potongan transkrip baru ke akumulasi.
  void appendTranscript(String transcript) {
    final t = transcript.trim();
    if (t.isEmpty) return;
    _accumulatedTranscript = _accumulatedTranscript.isEmpty
        ? t
        : '$_accumulatedTranscript $t';
  }

  /// Reset akumulasi transkrip.
  void clearAccumulated() {
    _accumulatedTranscript = '';
  }

  // ─── Verse progression ────────────────────────────────────────────────────

  /// Nomor ayat aktif berikutnya yang belum ter-reveal, atau -1 bila habis.
  int nextActiveVerse(int totalVerses) {
    for (var i = 0; i < totalVerses; i++) {
      if (!_revealed.contains(i)) return i + 1;
    }
    return -1;
  }

  /// Mulai murojaah: sembunyikan seluruh ayat, ayat aktif = 1.
  void start({required int surahNumber, required int totalVerses}) {
    _revealed.clear();
    _incorrectAttempts = 0;
    _accumulatedTranscript = '';
    value = MurojaahState.running(
      surahNumber: surahNumber,
      totalVerses: totalVerses,
      activeVerse: 1,
    );
  }

  /// Reveal hanya bila `verseIndex` sesuai urutan (ayat aktif).
  bool tryReveal(
    int verseIndex, {
    required int surahNumber,
    required int totalVerses,
    MatchResult matchResult = MatchResult.accept,
  }) {
    final next = nextActiveVerse(totalVerses);
    if (verseIndex != next) return false;
    _revealed.add(verseIndex - 1);
    _incorrectAttempts = 0;
    _accumulatedTranscript = '';
    final allRevealed = _revealed.length == totalVerses;
    value = MurojaahState(
      phase: allRevealed ? MurojaahPhase.completed : MurojaahPhase.running,
      status: MurojaahStatus.idle,
      surahNumber: surahNumber,
      totalVerses: totalVerses,
      activeVerse: allRevealed ? null : nextActiveVerse(totalVerses),
      revealedVerses: _revealed.length,
      matchResult: matchResult,
    );
    return true;
  }

  /// Reveal ayat aktif & maju ke ayat berikutnya.
  void markCorrect({
    required int surahNumber,
    required int totalVerses,
    MatchResult matchResult = MatchResult.accept,
  }) {
    final next = nextActiveVerse(totalVerses);
    if (next == -1) return;
    tryReveal(
      next,
      surahNumber: surahNumber,
      totalVerses: totalVerses,
      matchResult: matchResult,
    );
  }

  // ─── Matching engine ──────────────────────────────────────────────────────

  /// Validasi bacaan via Arabic matching (Pipeline A).
  ///
  /// ACCEPT → reveal & maju, kembalikan true.
  /// ALMOST / REJECT → tetap di ayat aktif, counter bertambah, kembalikan false.
  ///
  /// Sesuai MUROJAAH_RULES section 12 & 18 — logika matching ada di
  /// controller, bukan di page.
  bool validateArabic({
    required String transcript,
    required String expectedArabic,
    required int surahNumber,
    required int totalVerses,
  }) {
    final result = ArabicMatcher.matchArabic(
      expected: expectedArabic,
      transcript: transcript,
      surahNumber: surahNumber,
    );
    return _applyResult(
      result: result,
      surahNumber: surahNumber,
      totalVerses: totalVerses,
    );
  }

  /// Validasi bacaan via Latin matching (Pipeline B).
  ///
  /// Digunakan sebagai fallback atau primary bila transliteration tersedia.
  /// [verseNormalized] adalah [Verse.normalizedText] pre-computed.
  bool validateLatin({
    required String transcript,
    required String verseNormalized,
    required int surahNumber,
    required int totalVerses,
  }) {
    if (verseNormalized.isEmpty) {
      // Fallback ke Arabic matching bila transliteration belum tersedia.
      return false;
    }
    final result = ArabicMatcher.matchLatin(
      verseNormalized: verseNormalized,
      transcript: transcript,
    );
    return _applyResult(
      result: result,
      surahNumber: surahNumber,
      totalVerses: totalVerses,
    );
  }

  /// Validasi multi-layer: coba Arabic dulu, lalu Latin sebagai fallback.
  ///
  /// Sesuai MUROJAAH_RULES section 9:
  /// Arabic matching → jika reject → Latin matching → combined result.
  bool validate({
    required String transcript,
    required String expectedArabic,
    required String verseNormalized,
    required int surahNumber,
    required int totalVerses,
  }) {
    // Pipeline A: Arabic matching
    final arabicResult = ArabicMatcher.matchArabic(
      expected: expectedArabic,
      transcript: transcript,
      surahNumber: surahNumber,
    );

    // Jika Arabic accept/almost, gunakan hasilnya langsung.
    if (arabicResult != MatchResult.reject) {
      return _applyResult(
        result: arabicResult,
        surahNumber: surahNumber,
        totalVerses: totalVerses,
      );
    }

    // Pipeline B: Latin matching sebagai fallback (bila tersedia).
    if (verseNormalized.isNotEmpty) {
      final latinResult = ArabicMatcher.matchLatin(
        verseNormalized: verseNormalized,
        transcript: transcript,
      );
      if (latinResult != MatchResult.reject) {
        return _applyResult(
          result: latinResult,
          surahNumber: surahNumber,
          totalVerses: totalVerses,
        );
      }
    }

    // Kedua pipeline reject.
    return _applyResult(
      result: MatchResult.reject,
      surahNumber: surahNumber,
      totalVerses: totalVerses,
    );
  }

  /// Apply MatchResult ke state — reveal jika accept, update feedback jika tidak.
  bool _applyResult({
    required MatchResult result,
    required int surahNumber,
    required int totalVerses,
  }) {
    if (result == MatchResult.accept) {
      markCorrect(
        surahNumber: surahNumber,
        totalVerses: totalVerses,
        matchResult: result,
      );
      return true;
    }
    _incorrectAttempts++;
    final current = value;
    value = MurojaahState(
      phase: current.phase,
      status: current.status,
      surahNumber: current.surahNumber,
      activeVerse: current.activeVerse,
      totalVerses: current.totalVerses,
      revealedVerses: current.revealedVerses,
      matchResult: result,
    );
    return false;
  }

  // ─── MurojaahMatcher (new engine) ─────────────────────────────────────────

  /// Validasi bacaan menggunakan [MurojaahMatcher] (mesin baru tervalidasi).
  ///
  /// [isFinal] harus `true` untuk hasil final ASR. Hasil interim (`false`)
  /// diabaikan — ayat TIDAK maju berdasarkan transkrip sementara.
  ///
  /// ACCEPT  → reveal ayat aktif & maju ke ayat berikutnya, kembalikan true.
  /// RETRY   → tetap di ayat aktif, counter bertambah, kembalikan false.
  /// REJECT  → tetap di ayat aktif, counter bertambah, kembalikan false.
  ///
  /// Raw [transcript] diteruskan langsung ke matcher; normalisasi ada di domain.
  bool validateWithMatcher({
    required String transcript,
    required String expectedArabic,
    required int surahNumber,
    required int totalVerses,
    bool isFinal = true,
  }) {
    // Interim ASR results must NOT advance the verse.
    if (!isFinal) return false;

    final result = MurojaahMatcher.match(expectedArabic, transcript);
    return _applyMurojaahDecision(
      decision: result.decision,
      surahNumber: surahNumber,
      totalVerses: totalVerses,
    );
  }

  /// Apply [MurojaahDecision] ke state.
  ///
  /// ACCEPT  → reveal & maju, kembalikan true.
  /// RETRY   → tetap, counter bertambah, kembalikan false.
  /// REJECT  → tetap, counter bertambah, kembalikan false.
  bool _applyMurojaahDecision({
    required MurojaahDecision decision,
    required int surahNumber,
    required int totalVerses,
  }) {
    if (decision == MurojaahDecision.accept) {
      final next = nextActiveVerse(totalVerses);
      if (next == -1) return false;
      _revealed.add(next - 1);
      _incorrectAttempts = 0;
      _accumulatedTranscript = '';
      final allRevealed = _revealed.length == totalVerses;
      value = MurojaahState(
        phase: allRevealed ? MurojaahPhase.completed : MurojaahPhase.running,
        status: MurojaahStatus.idle,
        surahNumber: surahNumber,
        totalVerses: totalVerses,
        activeVerse: allRevealed ? null : nextActiveVerse(totalVerses),
        revealedVerses: _revealed.length,
        murojaahDecision: decision,
      );
      return true;
    }

    // RETRY or REJECT: stay on current verse.
    _incorrectAttempts++;
    final current = value;
    value = MurojaahState(
      phase: current.phase,
      status: current.status,
      surahNumber: current.surahNumber,
      activeVerse: current.activeVerse,
      totalVerses: current.totalVerses,
      revealedVerses: current.revealedVerses,
      murojaahDecision: decision,
    );
    return false;
  }

  // ─── Feedback & reset ─────────────────────────────────────────────────────

  /// Sembunyikan umpan balik (dipanggil saat mulai bicara ulang).
  void clearFeedback() {
    final current = value;
    if (current.matchResult == null && current.murojaahDecision == null) return;
    value = MurojaahState(
      phase: current.phase,
      status: current.status,
      surahNumber: current.surahNumber,
      activeVerse: current.activeVerse,
      totalVerses: current.totalVerses,
      revealedVerses: current.revealedVerses,
    );
  }

  /// Reveal satu ayat berikutnya (debug). Berurutan dari ayat 1.
  void revealNext({required int surahNumber, required int totalVerses}) {
    markCorrect(surahNumber: surahNumber, totalVerses: totalVerses);
  }

  /// Sembunyikan kembali seluruh ayat (reset reveal).
  void resetReveal({required int surahNumber, required int totalVerses}) {
    _revealed.clear();
    _incorrectAttempts = 0;
    _accumulatedTranscript = '';
    value = MurojaahState.running(
      surahNumber: surahNumber,
      totalVerses: totalVerses,
      activeVerse: 1,
    );
  }
}

/// Immutable state module Murojaah (tanpa freezed).
class MurojaahState {
  const MurojaahState({
    required this.phase,
    required this.status,
    this.surahNumber,
    this.activeVerse,
    this.totalVerses,
    this.revealedVerses = 0,
    this.errorMessage,
    this.matchResult,
    this.murojaahDecision,
  });

  const MurojaahState.initial()
      : this(
          phase: MurojaahPhase.initial,
          status: MurojaahStatus.idle,
        );

  const MurojaahState.running({
    required int surahNumber,
    required int totalVerses,
    required int activeVerse,
  }) : this(
          phase: MurojaahPhase.running,
          status: MurojaahStatus.idle,
          surahNumber: surahNumber,
          activeVerse: activeVerse,
          totalVerses: totalVerses,
        );

  const MurojaahState.error(String message)
      : this(
          phase: MurojaahPhase.initial,
          status: MurojaahStatus.error,
          errorMessage: message,
        );

  final MurojaahPhase phase;
  final MurojaahStatus status;
  final int? surahNumber;
  final int? activeVerse;
  final int? totalVerses;
  final int revealedVerses;
  final String? errorMessage;

  /// Hasil matching bacaan terakhir via ArabicMatcher.
  /// null saat belum ada validasi atau setelah clearFeedback().
  final MatchResult? matchResult;

  /// Hasil matching bacaan terakhir via MurojaahMatcher (mesin baru).
  /// null saat belum ada validasi via [validateWithMatcher] atau setelah
  /// clearFeedback().
  final MurojaahDecision? murojaahDecision;

  bool get isRunning => phase == MurojaahPhase.running;
  bool get isError => status == MurojaahStatus.error;

  // ─── MatchResult getters ──────────────────────────────────────────────────

  /// Apakah bacaan terakhir diterima (ArabicMatcher).
  bool get isAccepted => matchResult == MatchResult.accept;

  /// Apakah bacaan terakhir hampir benar (ArabicMatcher).
  bool get isAlmost => matchResult == MatchResult.almost;

  /// Apakah bacaan terakhir ditolak (ArabicMatcher).
  bool get isRejected => matchResult == MatchResult.reject;

  // ─── MurojaahDecision getters (new engine) ────────────────────────────────

  /// Apakah bacaan diterima oleh MurojaahMatcher.
  bool get isAcceptedByMatcher => murojaahDecision == MurojaahDecision.accept;

  /// Apakah bacaan perlu diulang (isolated deletion / RETRY).
  bool get isRetry => murojaahDecision == MurojaahDecision.retry;

  /// Apakah bacaan ditolak oleh MurojaahMatcher.
  bool get isRejectedByMatcher => murojaahDecision == MurojaahDecision.reject;
}
