/// audio_preprocessor.dart
///
/// Converts a 16-bit PCM WAV file (16 kHz, mono) into a normalised log-mel
/// spectrogram that matches the Python/librosa pipeline used in the POC:
///
///   librosa.feature.melspectrogram(
///     n_fft=512, hop_length=160, n_mels=80, fmin=0, fmax=8000,
///     center=True, pad_mode='constant', window='hann', power=2.0,
///   )
///   log(mel + 1e-9)
///   per-utterance mean/std normalisation
///
/// Reference output shape: (1, 80, T) where T = floor(samples / hop) + 1
/// For 8s @ 16kHz: T = floor(128000 / 160) + 1 = 801
library audio_preprocessor;

import 'dart:math' as math;
import 'dart:typed_data';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Result of preprocessing a WAV file.
class PreprocessedAudio {
  /// Normalised log-mel spectrogram, shape (1, nMels, T), row-major float32.
  final Float32List tensor;

  /// Number of mel bins (80).
  final int nMels;

  /// Number of time frames T.
  final int nFrames;

  /// Audio duration in seconds.
  final double durationSeconds;

  const PreprocessedAudio({
    required this.tensor,
    required this.nMels,
    required this.nFrames,
    required this.durationSeconds,
  });

  /// Flat index into [tensor] for mel bin [m] and time frame [t].
  int index(int m, int t) => m * nFrames + t;
}

/// Pre-computed mel filterbank (80 × 257 matrix, row-major).
///
/// Call [AudioPreprocessor.computeMelFilterbank] once and reuse across calls.
typedef MelFilterbank = Float32List;

/// Stateless preprocessor.  All methods are pure functions; state (filterbank,
/// Hann window, FFT twiddle factors) is precomputed once and passed in.
class AudioPreprocessor {
  // Pipeline constants — must match transcribe.py exactly.
  static const int sampleRate  = 16000;
  static const int nFft        = 512;
  static const int hopLength   = 160;
  static const int nMels       = 80;
  static const double fmin     = 0.0;
  static const double fmax     = 8000.0;
  static const double logOffset = 1e-9;
  static const int nFreqBins   = nFft ~/ 2 + 1; // 257

  // -------------------------------------------------------------------------
  // One-time setup helpers
  // -------------------------------------------------------------------------

  /// Hann window of length [nFft] (length 512).
  /// w[n] = 0.5 * (1 - cos(2π n / N))
  static Float32List buildHannWindow() {
    final w = Float32List(nFft);
    const double twoPiOverN = 2.0 * math.pi / nFft;
    for (int n = 0; n < nFft; n++) {
      w[n] = 0.5 * (1.0 - math.cos(twoPiOverN * n));
    }
    return w;
  }

  /// Mel filterbank matrix, shape (nMels × nFreqBins) = (80 × 257), row-major.
  ///
  /// Matches librosa.filters.mel(htk=False, norm='slaney'):
  ///   - Linear mel scale (Slaney / O'Shaughnessy, NOT HTK)
  ///   - Triangular filters normalised by filter bandwidth (norm='slaney')
  static Float32List buildMelFilterbank() {
    // Slaney mel ↔ Hz conversion — matches librosa.hz_to_mel(htk=False) exactly.
    //
    // Slaney (1998) / O'Shaughnessy formula:
    //   linear below 1000 Hz:  mel = hz / (200/3)
    //   log    above 1000 Hz:  mel = 15 + log(hz/1000) / log(6.4/27)
    //
    // CRITICAL: logStep = log(6.4) / 27.0  — NOT ln2/6.
    // librosa source (core/convert.py): logstep = np.log(6.4) / 27.0
    double hzToMel(double hz) {
      const double fsp      = 200.0 / 3.0;   // linear slope: ~66.667 Hz/mel
      const double minLogHz = 1000.0;
      const double minLogMel = minLogHz / fsp; // 15.0
      const double logStep  = 0.06875177742616539; // log(6.4)/27
      if (hz < minLogHz) return hz / fsp;
      return minLogMel + math.log(hz / minLogHz) / logStep;
    }

    double melToHz(double mel) {
      const double fsp      = 200.0 / 3.0;
      const double minLogHz = 1000.0;
      const double minLogMel = minLogHz / fsp;
      const double logStep  = 0.06875177742616539; // log(6.4)/27
      if (mel < minLogMel) return fsp * mel;
      return minLogHz * math.exp(logStep * (mel - minLogMel));
    }

    // nMels+2 linearly-spaced mel points from fmin to fmax
    // Matches: librosa.mel_frequencies(n_mels+2, fmin, fmax, htk=False)
    final double melMin = hzToMel(fmin);
    final double melMax = hzToMel(fmax);
    final List<double> melPoints = List.generate(
      nMels + 2,
      (i) => melMin + i * (melMax - melMin) / (nMels + 1),
    );

    // Convert mel points to Hz
    final List<double> melHz = melPoints.map(melToHz).toList();

    // FFT bin centre frequencies: fftfreqs[k] = k * sr / n_fft
    // Matches: librosa.fft_frequencies(sr=sr, n_fft=n_fft)
    // = np.linspace(0, sr/2, n_fft//2+1)  (same thing for power-of-2 n_fft)
    // We work entirely in Hz space, not fractional bins.

    // Build (nMels × nFreqBins) filterbank in Hz space
    final weights = Float32List(nMels * nFreqBins);

    for (int m = 0; m < nMels; m++) {
      final double hzLeft   = melHz[m];
      final double hzCenter = melHz[m + 1];
      final double hzRight  = melHz[m + 2];

      // Slaney norm: scale = 2 / (hzRight - hzLeft)
      final double bandwidth = hzRight - hzLeft;
      final double scale = bandwidth > 0.0 ? 2.0 / bandwidth : 0.0;

      for (int k = 0; k < nFreqBins; k++) {
        // fftfreqs[k] = k * sampleRate / nFft  (exact linspace formula)
        final double f = k * sampleRate / nFft.toDouble();
        double w = 0.0;
        if (f >= hzLeft && f <= hzCenter) {
          final double denom = hzCenter - hzLeft;
          w = denom > 0.0 ? (f - hzLeft) / denom : 0.0;
        } else if (f > hzCenter && f <= hzRight) {
          final double denom = hzRight - hzCenter;
          w = denom > 0.0 ? (hzRight - f) / denom : 0.0;
        }
        weights[m * nFreqBins + k] = w * scale;
      }
    }

    return weights;
  }

  // -------------------------------------------------------------------------
  // WAV parsing
  // -------------------------------------------------------------------------

  /// Parse a 16-bit PCM WAV file and return samples as float32 in [-1, 1].
  ///
  /// Supports only mono 16-bit PCM at 16 kHz (the only format used by the
  /// Quran ASR test files).  Throws [FormatException] on anything else.
  static Float32List parsePcm16Wav(Uint8List bytes) {
    if (bytes.length < 44) throw const FormatException('WAV too short');

    final bd = bytes.buffer.asByteData();

    // RIFF header
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    if (riff != 'RIFF') throw const FormatException('Not a RIFF file');
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (wave != 'WAVE') throw const FormatException('Not a WAVE file');

    // Walk chunks to find 'fmt ' and 'data'
    int pos = 12;
    int channels = -1, sr = -1, bitsPerSample = -1;
    int dataOffset = -1, dataSize = -1;

    while (pos + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(pos, pos + 4));
      final chunkSize = bd.getUint32(pos + 4, Endian.little);
      pos += 8;

      if (chunkId == 'fmt ') {
        final audioFormat = bd.getUint16(pos, Endian.little);
        if (audioFormat != 1) {
          throw FormatException('Only PCM (format 1) supported, got $audioFormat');
        }
        channels     = bd.getUint16(pos + 2, Endian.little);
        sr           = bd.getInt32(pos + 4, Endian.little);
        bitsPerSample = bd.getUint16(pos + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = pos;
        dataSize   = chunkSize;
        break;
      }

      pos += chunkSize;
      if (chunkSize % 2 != 0) pos++; // RIFF padding
    }

    if (dataOffset < 0) throw const FormatException('No data chunk found');
    if (channels != 1) throw FormatException('Only mono supported, got $channels channels');
    if (sr != sampleRate) throw FormatException('Expected $sampleRate Hz, got $sr Hz');
    if (bitsPerSample != 16) throw FormatException('Only 16-bit PCM supported, got $bitsPerSample-bit');

    final nSamples = dataSize ~/ 2;
    final samples = Float32List(nSamples);
    for (int i = 0; i < nSamples; i++) {
      final s = bd.getInt16(dataOffset + i * 2, Endian.little);
      samples[i] = s / 32768.0;
    }
    return samples;
  }

  // -------------------------------------------------------------------------
  // STFT / FFT
  // -------------------------------------------------------------------------

  /// Iterative Cooley-Tukey radix-2 DIT FFT, in-place on [re] and [im].
  ///
  /// [n] must be a power of 2.  Both arrays must have length >= [n].
  /// Twiddle factors are computed on-the-fly (no pre-allocation needed
  /// beyond the input buffers themselves).
  static void _fftInPlace(Float64List re, Float64List im, int n) {
    // Bit-reversal permutation
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      while (j >= bit) {
        j -= bit;
        bit >>= 1;
      }
      j += bit;
      if (i < j) {
        double t = re[i]; re[i] = re[j]; re[j] = t;
        t = im[i]; im[i] = im[j]; im[j] = t;
      }
    }

    // Cooley-Tukey butterfly
    for (int len = 2; len <= n; len <<= 1) {
      final double ang = -2.0 * math.pi / len;
      final double wRe = math.cos(ang);
      final double wIm = math.sin(ang);
      for (int i = 0; i < n; i += len) {
        double curRe = 1.0, curIm = 0.0;
        for (int k = 0; k < len ~/ 2; k++) {
          final double uRe = re[i + k];
          final double uIm = im[i + k];
          final double vRe = re[i + k + len ~/ 2] * curRe - im[i + k + len ~/ 2] * curIm;
          final double vIm = re[i + k + len ~/ 2] * curIm + im[i + k + len ~/ 2] * curRe;
          re[i + k]           = uRe + vRe;
          im[i + k]           = uIm + vIm;
          re[i + k + len ~/ 2] = uRe - vRe;
          im[i + k + len ~/ 2] = uIm - vIm;
          final double newRe = curRe * wRe - curIm * wIm;
          curIm = curRe * wIm + curIm * wRe;
          curRe = newRe;
        }
      }
    }
  }

  // -------------------------------------------------------------------------
  // Full pipeline
  // -------------------------------------------------------------------------

  /// Run the full preprocessing pipeline on [samples] (float32 PCM, 16 kHz).
  ///
  /// Parameters:
  ///   [hannWindow]   — precomputed Hann window (call [buildHannWindow] once)
  ///   [melFilterbank] — precomputed filterbank (call [buildMelFilterbank] once)
  ///
  /// Returns a [PreprocessedAudio] whose [tensor] is ready to be passed to
  /// [OrtValue.fromList] with shape `[1, nMels, nFrames]`.
  static PreprocessedAudio process({
    required Float32List samples,
    required Float32List hannWindow,
    required Float32List melFilterbank,
  }) {
    final int nSamples = samples.length;
    final double duration = nSamples / sampleRate;

    // --- center=True padding (librosa default) ---
    // Pad by nFft/2 on each side with zeros ('constant' pad_mode)
    final int pad = nFft ~/ 2; // 256
    final int paddedLen = nSamples + 2 * pad;
    final Float32List padded = Float32List(paddedLen);
    padded.setRange(pad, pad + nSamples, samples);

    // Number of frames: floor((paddedLen - nFft) / hop) + 1
    final int nFrames = (paddedLen - nFft) ~/ hopLength + 1;

    // Reusable FFT buffers (length nFft = 512)
    final re = Float64List(nFft);
    final im = Float64List(nFft);

    // Power spectrum accumulator: (nFreqBins × nFrames)
    // We will fill column by column.
    final powerSpec = Float32List(nFreqBins * nFrames);

    for (int frame = 0; frame < nFrames; frame++) {
      final int start = frame * hopLength;

      // Apply Hann window
      for (int n = 0; n < nFft; n++) {
        re[n] = padded[start + n] * hannWindow[n];
        im[n] = 0.0;
      }

      // FFT in-place
      _fftInPlace(re, im, nFft);

      // Power spectrum |X[k]|² for k = 0..nFreqBins-1
      for (int k = 0; k < nFreqBins; k++) {
        powerSpec[k * nFrames + frame] = re[k] * re[k] + im[k] * im[k];
      }
    }

    // --- Apply mel filterbank: mel[m,t] = sum_k filterbank[m,k] * power[k,t] ---
    final melSpec = Float32List(nMels * nFrames);
    for (int m = 0; m < nMels; m++) {
      final int mRow = m * nFreqBins;
      for (int t = 0; t < nFrames; t++) {
        double sum = 0.0;
        for (int k = 0; k < nFreqBins; k++) {
          sum += melFilterbank[mRow + k] * powerSpec[k * nFrames + t];
        }
        melSpec[m * nFrames + t] = sum;
      }
    }

    // --- Log compression: log(mel + 1e-9) ---
    for (int i = 0; i < melSpec.length; i++) {
      melSpec[i] = math.log(melSpec[i] + logOffset);
    }

    // --- Per-utterance normalisation: (x - mean) / (std + 1e-9) ---
    double sum = 0.0;
    for (int i = 0; i < melSpec.length; i++) sum += melSpec[i];
    final double mean = sum / melSpec.length;

    double sumSq = 0.0;
    for (int i = 0; i < melSpec.length; i++) {
      final double d = melSpec[i] - mean;
      sumSq += d * d;
    }
    final double std = math.sqrt(sumSq / melSpec.length);
    final double scale = 1.0 / (std + logOffset);

    for (int i = 0; i < melSpec.length; i++) {
      melSpec[i] = (melSpec[i] - mean) * scale;
    }

    // --- Wrap in batch dimension: shape (1, nMels, nFrames) ---
    // melSpec is already (nMels, nFrames) row-major, so just return it
    // — the batch dimension is represented by the shape metadata only.

    return PreprocessedAudio(
      tensor: melSpec,
      nMels: nMels,
      nFrames: nFrames,
      durationSeconds: duration,
    );
  }

  /// Convenience: parse a WAV [bytes] buffer and run [process] in one call.
  ///
  /// Precomputes the Hann window and mel filterbank on every call, so use
  /// this only for one-shot processing.  For repeated calls, precompute with
  /// [buildHannWindow] / [buildMelFilterbank] and call [process] directly.
  static PreprocessedAudio processWavBytes({
    required Uint8List bytes,
    Float32List? hannWindow,
    Float32List? melFilterbank,
  }) {
    final samples = parsePcm16Wav(bytes);
    return process(
      samples: samples,
      hannWindow: hannWindow ?? buildHannWindow(),
      melFilterbank: melFilterbank ?? buildMelFilterbank(),
    );
  }
}
