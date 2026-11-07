import 'dart:async';

import 'package:flutter/foundation.dart';

import '../recite/recite_session_controller.dart';
import '../recite/recite_session_engine.dart';

/// Pendengar bacaan satu ayat. `true` = benar, `false` = salah, null = gagal
/// (mis. izin mikrofon ditolak) atau dibatalkan.
abstract class AyatRecognizer {
  Future<bool?> listen(int ayat);
  Future<void> cancel();
}

/// Penghubung ke pipeline ASR yang sudah ada: [ReciteSessionController] +
/// [ReciteSessionEngine]. Tidak mengubah matcher maupun ambang penilaian.
class ReciteAyatRecognizer implements AyatRecognizer {
  ReciteAyatRecognizer({required this.session, required this.engine});

  final ReciteSessionController session;
  final ReciteSessionEngine engine;
  Completer<bool?>? _pending;

  @override
  Future<bool?> listen(int ayat) async {
    await cancel();
    session.adoptVerses();
    session.startVerseAttempt(ayat - 1);
    final done = _pending = Completer<bool?>();
    void check() {
      final o = session.verseOutcome(ayat - 1);
      if (o != VerseOutcome.pending && !done.isCompleted) {
        done.complete(o == VerseOutcome.correct);
      }
    }

    session.addListener(check);
    try {
      await engine.startListening();
      if (engine.status.value == ReciteMurojaahStatus.error) {
        if (!done.isCompleted) done.complete(null);
      }
      return await done.future;
    } finally {
      session.removeListener(check);
      if (identical(_pending, done)) _pending = null;
      await engine.stopListening();
    }
  }

  @override
  Future<void> cancel() async {
    final p = _pending;
    if (p != null && !p.isCompleted) p.complete(null);
  }
}

enum TirukanPhase { idle, listening, gap, recording, correct, retry, finished, error }

/// Alur "Dengar lalu Tirukan" (BL-08): putar ayat → jeda → rekam → nilai →
/// ayat berikutnya (benar) atau putar ulang ayat yang sama (salah).
class DengarTirukanFlow extends ChangeNotifier {
  DengarTirukanFlow({
    required this.totalAyat,
    required this.playAyat,
    required this.stopAudio,
    required this.recognizer,
    required this.gap,
    this.startAyat = 1,
    this.wait = _delay,
    this.feedback = const Duration(milliseconds: 1200),
  }) : _ayat = startAyat;

  final int totalAyat;

  /// Putar satu ayat; true bila audio selesai, false bila gagal/dihentikan.
  final Future<bool> Function(int ayat) playAyat;
  final Future<void> Function() stopAudio;
  final AyatRecognizer recognizer;

  /// Jeda sebelum mikrofon menyala (BL-04), dibaca tiap putaran.
  final Duration Function() gap;
  final int startAyat;
  final Future<void> Function(Duration) wait;

  /// Lama pesan "Benar"/"Coba lagi" tampil sebelum langkah berikutnya.
  final Duration feedback;

  static Future<void> _delay(Duration d) => Future<void>.delayed(d);

  int _ayat;
  TirukanPhase _phase = TirukanPhase.idle;
  bool _stopped = true;
  int _run = 0;

  int get ayat => _ayat;
  TirukanPhase get phase => _phase;

  void _set(TirukanPhase p) {
    _phase = p;
    notifyListeners();
  }

  /// Jalankan sampai selesai, error, atau [stop].
  Future<void> start() async {
    final run = ++_run;
    _stopped = false;
    bool alive() => !_stopped && run == _run;

    while (alive()) {
      _set(TirukanPhase.listening);
      final played = await playAyat(_ayat);
      if (!alive()) return;
      if (!played) return _set(TirukanPhase.error);

      final g = gap();
      if (g > Duration.zero) {
        _set(TirukanPhase.gap);
        await wait(g);
        if (!alive()) return;
      }

      _set(TirukanPhase.recording);
      final ok = await recognizer.listen(_ayat);
      if (!alive()) return;
      if (ok == null) return _set(TirukanPhase.error);

      if (ok && _ayat >= totalAyat) return _set(TirukanPhase.finished);
      _set(ok ? TirukanPhase.correct : TirukanPhase.retry);
      await wait(feedback);
      if (!alive()) return;
      if (ok) _ayat++;
    }
  }

  /// Hentikan audio dan mikrofon.
  Future<void> stop() async {
    _stopped = true;
    await recognizer.cancel();
    await stopAudio();
    if (_phase != TirukanPhase.finished) _set(TirukanPhase.idle);
  }
}
