/// wav_encoder.dart
///
/// Pure-Dart RIFF WAV encoder for debug purposes only.
///
/// Converts a [MurojaahAudioBuffer] to a standard 16-bit PCM WAV [Uint8List]
/// that can be written to disk, played back, or compared against reference
/// recordings.
///
/// This is NOT part of the inference pipeline — it exists only for the
/// optional "Save WAV" debugging action on [AudioCapturePocPage].
library wav_encoder;

import 'dart:typed_data';

import 'murojaah_audio_buffer.dart';

class WavEncoder {
  WavEncoder._();

  /// Encode [buffer] as a 16-bit PCM RIFF WAV [Uint8List].
  ///
  /// Output: 44-byte header + int16 LE sample data.
  static Uint8List encode(MurojaahAudioBuffer buffer) {
    final int numSamples    = buffer.sampleCount;
    final int sampleRate    = buffer.sampleRate;
    final int numChannels   = buffer.channels;
    const int bitsPerSample = 16;
    final int byteRate      = sampleRate * numChannels * bitsPerSample ~/ 8;
    final int blockAlign    = numChannels * bitsPerSample ~/ 8;
    final int dataSize      = numSamples * blockAlign;
    final int fileSize      = 44 + dataSize;

    final bytes = Uint8List(fileSize);
    final bd    = bytes.buffer.asByteData();

    // RIFF chunk
    _writeAscii(bytes, 0, 'RIFF');
    bd.setUint32(4, fileSize - 8, Endian.little);
    _writeAscii(bytes, 8, 'WAVE');

    // fmt  chunk (16 bytes, PCM)
    _writeAscii(bytes, 12, 'fmt ');
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1,  Endian.little);          // PCM = 1
    bd.setUint16(22, numChannels, Endian.little);
    bd.setUint32(24, sampleRate,  Endian.little);
    bd.setUint32(28, byteRate,    Endian.little);
    bd.setUint16(32, blockAlign,  Endian.little);
    bd.setUint16(34, bitsPerSample, Endian.little);

    // data chunk
    _writeAscii(bytes, 36, 'data');
    bd.setUint32(40, dataSize, Endian.little);

    // Samples: float32 → int16 LE
    int offset = 44;
    for (int i = 0; i < numSamples; i++) {
      final double s = buffer.samples[i].clamp(-1.0, 1.0);
      final int pcm  = (s * 32767.0).round().clamp(-32768, 32767);
      bd.setInt16(offset, pcm, Endian.little);
      offset += 2;
    }

    return bytes;
  }

  static void _writeAscii(Uint8List bytes, int offset, String text) {
    for (int i = 0; i < text.length; i++) {
      bytes[offset + i] = text.codeUnitAt(i);
    }
  }
}
