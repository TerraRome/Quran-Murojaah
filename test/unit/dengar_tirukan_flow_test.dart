import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/tirukan/dengar_tirukan_flow.dart';

class _FakeRecognizer implements AyatRecognizer {
  _FakeRecognizer(this.results);
  final List<bool?> results;
  final listened = <int>[];
  int cancels = 0;

  @override
  Future<bool?> listen(int ayat) async {
    listened.add(ayat);
    return results.removeAt(0);
  }

  @override
  Future<void> cancel() async => cancels++;
}

void main() {
  late List<String> log;
  late List<Duration> waits;

  DengarTirukanFlow make(
    _FakeRecognizer r, {
    int total = 2,
    Duration gap = Duration.zero,
    Future<bool> Function(int)? play,
    List<TirukanPhase>? phases,
  }) {
    final flow = DengarTirukanFlow(
      totalAyat: total,
      recognizer: r,
      gap: () => gap,
      wait: (d) async => waits.add(d),
      stopAudio: () async => log.add('stop'),
      playAyat: play ??
          (a) async {
            log.add('play$a');
            return true;
          },
    );
    if (phases != null) flow.addListener(() => phases.add(flow.phase));
    return flow;
  }

  setUp(() {
    log = [];
    waits = [];
  });

  test('benar -> ayat berikutnya; ayat terakhir benar -> selesai', () async {
    final r = _FakeRecognizer([true, true]);
    final flow = make(r);
    await flow.start();
    expect(log, ['play1', 'play2']);
    expect(r.listened, [1, 2]);
    expect(flow.phase, TirukanPhase.finished);
  });

  test('salah -> ayat yang sama diputar ulang', () async {
    final r = _FakeRecognizer([false, false, true, true]);
    final flow = make(r);
    await flow.start();
    expect(log, ['play1', 'play1', 'play1', 'play2']);
    expect(r.listened, [1, 1, 1, 2]);
    expect(flow.phase, TirukanPhase.finished);
  });

  test('urutan fase: dengar -> rekam -> benar', () async {
    final phases = <TirukanPhase>[];
    final flow = make(_FakeRecognizer([true]), total: 1, phases: phases);
    await flow.start();
    expect(phases, [
      TirukanPhase.listening,
      TirukanPhase.recording,
      TirukanPhase.finished,
    ]);
  });

  test('jeda (BL-04) ditunggu sebelum mikrofon menyala', () async {
    final phases = <TirukanPhase>[];
    final flow = make(
      _FakeRecognizer([true]),
      total: 1,
      gap: const Duration(seconds: 3),
      phases: phases,
    );
    await flow.start();
    expect(waits, [const Duration(seconds: 3)]);
    expect(phases, contains(TirukanPhase.gap));
    expect(phases.indexOf(TirukanPhase.gap),
        lessThan(phases.indexOf(TirukanPhase.recording)));
  });

  test('audio gagal -> error, mikrofon tidak menyala', () async {
    final r = _FakeRecognizer([]);
    final flow = make(r, play: (_) async => false);
    await flow.start();
    expect(flow.phase, TirukanPhase.error);
    expect(r.listened, isEmpty);
  });

  test('recognizer gagal (izin mic) -> error', () async {
    final flow = make(_FakeRecognizer([null]));
    await flow.start();
    expect(flow.phase, TirukanPhase.error);
  });

  test('stop membatalkan audio & mikrofon dan menghentikan alur', () async {
    late DengarTirukanFlow flow;
    final r = _FakeRecognizer([true, true]);
    flow = make(r, play: (a) async {
      log.add('play$a');
      await flow.stop(); // pengguna menekan berhenti saat audio berjalan
      return true;
    });
    await flow.start();
    expect(r.cancels, 1);
    expect(log, ['play1', 'stop']);
    expect(r.listened, isEmpty);
    expect(flow.phase, TirukanPhase.idle);
  });
}
