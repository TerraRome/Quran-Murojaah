// murojaah_audio_recorder_test.dart
//
// Unit tests for MurojaahAudioRecorder interface contract and FakeAudioRecorder.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_portfolio/Quran/murojaah/infrastructure/audio/murojaah_audio_buffer.dart';
import 'package:flutter_portfolio/Quran/murojaah/infrastructure/audio/murojaah_audio_recorder.dart';

void main() {
  group('FakeAudioRecorder — permission', () {
    test('requestPermission returns true by default', () async {
      final rec = FakeAudioRecorder();
      expect(await rec.requestPermission(), isTrue);
    });
  });

  group('FakeAudioRecorder — lifecycle: happy path', () {
    late FakeAudioRecorder rec;

    setUp(() {
      final s = Float32List(16000);
      rec = FakeAudioRecorder(fakeSamples: s, fakeSampleRate: 16000, fakeChannels: 1);
    });

    test('isRecording is false before start', () async {
      await rec.initialize();
      expect(rec.isRecording, isFalse);
    });

    test('isRecording is true after start', () async {
      await rec.initialize();
      await rec.start();
      expect(rec.isRecording, isTrue);
    });

    test('isRecording is false after stop', () async {
      await rec.initialize();
      await rec.start();
      await rec.stop();
      expect(rec.isRecording, isFalse);
    });

    test('stop returns MurojaahAudioBuffer with correct sampleRate', () async {
      await rec.initialize();
      await rec.start();
      final buf = await rec.stop();
      expect(buf.sampleRate, 16000);
    });

    test('stop returns MurojaahAudioBuffer with correct channels', () async {
      await rec.initialize();
      await rec.start();
      final buf = await rec.stop();
      expect(buf.channels, 1);
    });

    test('stop returns buffer with provided samples', () async {
      final expected = Float32List.fromList([0.1, 0.2, 0.3]);
      final r = FakeAudioRecorder(fakeSamples: expected);
      await r.initialize();
      await r.start();
      final buf = await r.stop();
      expect(buf.sampleCount, 3);
      expect(buf.samples[0], closeTo(0.1, 1e-6));
      expect(buf.samples[1], closeTo(0.2, 1e-6));
      expect(buf.samples[2], closeTo(0.3, 1e-6));
    });

    test('can start and stop multiple times', () async {
      await rec.initialize();
      await rec.start();
      final buf1 = await rec.stop();
      await rec.start();
      final buf2 = await rec.stop();
      expect(buf1.sampleRate, 16000);
      expect(buf2.sampleRate, 16000);
    });
  });

  group('FakeAudioRecorder — error states', () {
    test('start before initialize throws StateError', () async {
      final rec = FakeAudioRecorder();
      expect(rec.start, throwsA(isA<StateError>()));
    });

    test('stop when not recording throws StateError', () async {
      final rec = FakeAudioRecorder();
      await rec.initialize();
      expect(rec.stop, throwsA(isA<StateError>()));
    });

    test('start when already recording throws StateError', () async {
      final rec = FakeAudioRecorder();
      await rec.initialize();
      await rec.start();
      expect(rec.start, throwsA(isA<StateError>()));
    });

    test('start with startError propagates the error', () async {
      final err = Exception('mic unavailable');
      final rec = FakeAudioRecorder(startError: err);
      await rec.initialize();
      expect(() => rec.start(), throwsA(same(err)));
    });
  });

  group('FakeAudioRecorder — disposed state', () {
    test('initialize after dispose throws StateError', () async {
      final rec = FakeAudioRecorder();
      await rec.dispose();
      expect(rec.initialize, throwsA(isA<StateError>()));
    });

    test('start after dispose throws StateError', () async {
      final rec = FakeAudioRecorder();
      await rec.initialize();
      await rec.dispose();
      expect(rec.start, throwsA(isA<StateError>()));
    });

    test('stop after dispose throws StateError', () async {
      final rec = FakeAudioRecorder();
      await rec.initialize();
      await rec.start();
      await rec.dispose();
      expect(rec.stop, throwsA(isA<StateError>()));
    });

    test('isRecording is false after dispose', () async {
      final rec = FakeAudioRecorder();
      await rec.initialize();
      await rec.start();
      await rec.dispose();
      expect(rec.isRecording, isFalse);
    });

    test('dispose can be called twice without error', () async {
      final rec = FakeAudioRecorder();
      await rec.dispose();
      await rec.dispose(); // should not throw
    });
  });

  group('FakeAudioRecorder — default fake samples', () {
    test('default fakeSamples is 16000 silent samples', () async {
      final rec = FakeAudioRecorder();
      await rec.initialize();
      await rec.start();
      final buf = await rec.stop();
      expect(buf.sampleCount, 16000);
      expect(buf.isEffectivelySilent, isTrue);
    });
  });

  group('MurojaahAudioBuffer returned by FakeAudioRecorder', () {
    late MurojaahAudioBuffer buf;

    setUpAll(() async {
      final s = Float32List(32000); // 2s of silence
      final rec = FakeAudioRecorder(fakeSamples: s, fakeSampleRate: 16000, fakeChannels: 1);
      await rec.initialize();
      await rec.start();
      buf = await rec.stop();
    });

    test('durationSeconds is 2.0', () => expect(buf.durationSeconds, closeTo(2.0, 1e-9)));
    test('sampleCount is 32000', () => expect(buf.sampleCount, 32000));
    test('rms is 0 for silence', () => expect(buf.rms, 0.0));
    test('peak is 0 for silence', () => expect(buf.peak, 0.0));
    test('silencePercentage is 100', () => expect(buf.silencePercentage, 100.0));
  });
}
