/// audio_capture_poc_page.dart
///
/// DEV-ONLY page for validating the live microphone capture pipeline on Android.
///
/// Pipeline under test:
///   Android Microphone
///     → RecordAudioRecorder
///     → MurojaahAudioBuffer
///     → AudioPreprocessor.process()
///     → QuranOnnxRecognizer.transcribeSamples()
///     → MurojaahMatcher.match()
///
/// Do NOT use this page as a template for production Murojaah UI.
/// Do NOT integrate with MurojaahController.
/// Do NOT implement VAD, automatic segmentation, or streaming inference.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/murojaah_matcher.dart';
import '../../infrastructure/asr/audio_preprocessor.dart';
import '../../infrastructure/asr/quran_asr_result.dart';
import '../../infrastructure/asr/quran_onnx_recognizer.dart';
import '../../infrastructure/audio/murojaah_audio_recorder.dart';
import '../../infrastructure/audio/record_audio_recorder.dart';
import '../../infrastructure/audio/wav_encoder.dart';

// ---------------------------------------------------------------------------
// Reference verse for matcher — Yasin 001 (Surah 36, Ayat 1)
// Same source as asr_e2e_runner_page.dart
// ---------------------------------------------------------------------------
const String _yasin001 = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ يسٓ';

// ---------------------------------------------------------------------------
// Page state enum
// ---------------------------------------------------------------------------
enum _PocState { idle, recording, captured, error }

// ---------------------------------------------------------------------------
// Data holders
// ---------------------------------------------------------------------------

class _PreprocessResult {
  final int nMels;
  final int nFrames;
  final int elapsedMs;
  const _PreprocessResult({
    required this.nMels,
    required this.nFrames,
    required this.elapsedMs,
  });
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class AudioCapturePocPage extends StatefulWidget {
  /// Inject a [MurojaahAudioRecorder] for testing.
  /// Production/dev route passes nothing — defaults to [RecordAudioRecorder].
  final MurojaahAudioRecorder _recorder;

  AudioCapturePocPage({super.key, MurojaahAudioRecorder? recorder})
    : _recorder = recorder ?? RecordAudioRecorder();

  @override
  State<AudioCapturePocPage> createState() => _AudioCapturePocPageState();
}

class _AudioCapturePocPageState extends State<AudioCapturePocPage> {
  // ONNX engine — created once, disposed on page exit
  final QuranOnnxRecognizer _engine = QuranOnnxRecognizer();

  _PocState _state = _PocState.idle;
  String _statusMessage = 'Idle — tap Start Recording to begin.';
  String? _errorMessage;

  MurojaahAudioBuffer? _buffer;
  String? _savedWavPath;
  _PreprocessResult? _preprocessResult;
  AsrInferenceResult? _asrResult;
  MurojaahMatchResult? _matchResult;

  bool _savingWav = false;
  bool _preprocessing = false;
  bool _runningAsr = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    try {
      final granted = await widget._recorder.requestPermission();
      if (!granted) {
        if (mounted) {
          setState(() {
            _state = _PocState.error;
            _statusMessage = 'Status: Error';
            _errorMessage =
                'Microphone permission denied. Grant access in device settings.';
          });
        }
        return;
      }
      await widget._recorder.initialize();
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _PocState.error;
          _statusMessage = 'Status: Error';
          _errorMessage = 'Recorder initialization failed: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    widget._recorder.dispose();
    _engine.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Recording actions
  // ---------------------------------------------------------------------------

  Future<void> _startRecording() async {
    if (_state == _PocState.recording) return;
    setState(() {
      _state = _PocState.recording;
      _statusMessage = 'Status: Recording…';
      _errorMessage = null;
      _buffer = null;
      _savedWavPath = null;
      _preprocessResult = null;
      _asrResult = null;
      _matchResult = null;
    });
    try {
      await widget._recorder.start();
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _PocState.error;
          _statusMessage = 'Status: Error';
          _errorMessage = 'Start failed: $e';
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_state != _PocState.recording) return;
    try {
      final buf = await widget._recorder.stop();

      // Validate format before accepting the buffer
      if (buf.sampleRate != AudioPreprocessor.sampleRate) {
        throw FormatException(
          'Expected ${AudioPreprocessor.sampleRate} Hz, '
          'got ${buf.sampleRate} Hz. Cannot run preprocessing.',
        );
      }
      if (buf.channels != 1) {
        throw FormatException(
          'Expected 1 channel (mono), got ${buf.channels}. '
          'Stereo downmix not implemented.',
        );
      }
      if (buf.samples.isEmpty) {
        throw StateError('Empty recording — no audio was captured.');
      }

      setState(() {
        _buffer = buf;
        _state = _PocState.captured;
        _statusMessage = 'Status: Captured';
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _PocState.error;
          _statusMessage = 'Status: Error';
          _errorMessage = 'Stop failed: $e';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Save WAV (debug only)
  // ---------------------------------------------------------------------------

  Future<void> _saveWav() async {
    final buf = _buffer;
    if (buf == null) return;
    setState(() => _savingWav = true);
    try {
      final wavBytes = WavEncoder.encode(buf);
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/debug_murojaah_recording.wav';
      await File(path).writeAsBytes(wavBytes, flush: true);
      if (mounted) {
        setState(() {
          _savedWavPath = path;
          _savingWav = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _savingWav = false;
          _errorMessage = 'Save WAV failed: $e';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Run Preprocessing (diagnostic only — independent of Run ASR)
  // ---------------------------------------------------------------------------

  Future<void> _runPreprocessing() async {
    final buf = _buffer;
    if (buf == null) return;
    setState(() {
      _preprocessing = true;
      _preprocessResult = null;
    });
    try {
      final sw = Stopwatch()..start();
      final audio = AudioPreprocessor.process(
        samples: buf.samples,
        hannWindow: AudioPreprocessor.buildHannWindow(),
        melFilterbank: AudioPreprocessor.buildMelFilterbank(),
      );
      sw.stop();
      if (mounted) {
        setState(() {
          _preprocessResult = _PreprocessResult(
            nMels: audio.nMels,
            nFrames: audio.nFrames,
            elapsedMs: sw.elapsedMilliseconds,
          );
          _preprocessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _preprocessing = false;
          _errorMessage = 'Preprocessing failed: $e';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Run ASR — independent of _runPreprocessing; always preprocesses fresh
  // ---------------------------------------------------------------------------

  Future<void> _runAsr() async {
    final buf = _buffer;
    if (buf == null) return;
    setState(() {
      _runningAsr = true;
      _asrResult = null;
      _matchResult = null;
    });
    try {
      final result = await _engine.transcribeSamples(
        buf.samples,
        durationSeconds: buf.durationSeconds,
      );
      final match = MurojaahMatcher.match(_yasin001, result.transcript);
      if (mounted) {
        setState(() {
          _asrResult = result;
          _matchResult = match;
          _runningAsr = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _runningAsr = false;
          _errorMessage = 'ASR failed: $e';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        title: const Text(
          '[DEV] Murojaah Audio Capture POC',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildStatusBar(),
          const SizedBox(height: 12),
          _buildRecordingButtons(),
          if (_state == _PocState.captured && _buffer != null) ...[
            const SizedBox(height: 16),
            _buildDiagnosticsSection(buffer: _buffer!),
            const SizedBox(height: 12),
            _buildCaptureActions(),
          ],
          if (_preprocessResult != null) ...[
            const SizedBox(height: 16),
            _buildPreprocessingSection(result: _preprocessResult!),
          ],
          if (_asrResult != null && _matchResult != null) ...[
            const SizedBox(height: 16),
            _buildAsrSection(asr: _asrResult!, match: _matchResult!),
          ],
          if (_savedWavPath != null) ...[
            const SizedBox(height: 8),
            _monospaceCard(
              'WAV saved:\n$_savedWavPath',
              color: Colors.green.shade700,
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            _monospaceCard('Error: $_errorMessage', color: Colors.red.shade700),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets (closures over state)
  // ---------------------------------------------------------------------------

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _statusMessage,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildRecordingButtons() {
    final isIdle = _state == _PocState.idle || _state == _PocState.captured;
    final isRecording = _state == _PocState.recording;
    final isError = _state == _PocState.error;
    final canStart = isIdle || isError;

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: canStart ? _startRecording : null,
            icon: const Icon(Icons.mic),
            label: const Text('Start Recording'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              disabledBackgroundColor: Colors.grey.shade300,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: isRecording ? _stopRecording : null,
            icon: const Icon(Icons.stop),
            label: const Text('Stop Recording'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              disabledBackgroundColor: Colors.grey.shade300,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _savingWav ? null : _saveWav,
          icon: _savingWav
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_alt),
          label: const Text('Save WAV'),
        ),
        OutlinedButton.icon(
          onPressed: _preprocessing ? null : _runPreprocessing,
          icon: _preprocessing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.tune),
          label: const Text('Run Preprocessing'),
        ),
        OutlinedButton.icon(
          onPressed: _runningAsr ? null : _runAsr,
          icon: _runningAsr
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.record_voice_over),
          label: const Text('Run ASR'),
        ),
      ],
    );
  }

  Widget _buildDiagnosticsSection({required MurojaahAudioBuffer buffer}) {
    return _Section(
      title: 'Audio',
      rows: [
        _Row('Sample Rate', '${buffer.sampleRate} Hz'),
        _Row('Channels', '${buffer.channels}'),
        _Row('Duration', '${buffer.durationSeconds.toStringAsFixed(2)} s'),
        _Row('Samples', '${buffer.sampleCount}'),
        _Row('RMS', buffer.rms.toStringAsFixed(4)),
        _Row('Peak', buffer.peak.toStringAsFixed(4)),
        _Row('Silence', '${buffer.silencePercentage.toStringAsFixed(1)}%'),
        _Row('Silent', buffer.isEffectivelySilent ? 'Yes' : 'No'),
      ],
    );
  }

  Widget _buildPreprocessingSection({required _PreprocessResult result}) {
    return _Section(
      title: 'Preprocessing',
      rows: [
        _Row('Tensor shape', '[1, ${result.nMels}, ${result.nFrames}]'),
        _Row('T', '${result.nFrames}'),
        _Row('Time', '${result.elapsedMs} ms'),
      ],
    );
  }

  Widget _buildAsrSection({
    required AsrInferenceResult asr,
    required MurojaahMatchResult match,
  }) {
    final rtf = asr.realtimeFactor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'ASR',
          rows: [
            _Row('Preprocess', '${asr.timings.preprocessMs} ms'),
            _Row('Inference', '${asr.timings.inferenceMs} ms'),
            _Row('Decode', '${asr.timings.decodeMs} ms'),
            _Row('Total', '${asr.timings.totalMs} ms'),
            _Row('RTF', rtf.toStringAsFixed(3)),
          ],
        ),
        const SizedBox(height: 8),
        const _SectionHeader('Transcript'),
        _arabicBox(asr.transcript),
        const SizedBox(height: 8),
        const _SectionHeader('Expected'),
        _arabicBox(_yasin001),
        const SizedBox(height: 8),
        _Section(
          title: 'Matcher',
          rows: [
            _Row('Score', match.effectiveScore.toStringAsFixed(4)),
            _Row('Decision', match.decision.name.toUpperCase()),
            _Row('Reason', match.reason),
          ],
          decisionColor: _decisionColor(match.decision),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable section widgets
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  final Color? decisionColor;

  const _Section({required this.title, required this.rows, this.decisionColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _monospaceCard(String text, {Color color = Colors.black87}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: color),
    ),
  );
}

Widget _arabicBox(String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      textDirection: TextDirection.rtl,
      style: const TextStyle(fontSize: 16, height: 1.8, color: Colors.black87),
    ),
  );
}

Color _decisionColor(MurojaahDecision decision) {
  return switch (decision) {
    MurojaahDecision.accept => Colors.green.shade700,
    MurojaahDecision.retry => Colors.orange.shade700,
    MurojaahDecision.reject => Colors.red.shade700,
  };
}
