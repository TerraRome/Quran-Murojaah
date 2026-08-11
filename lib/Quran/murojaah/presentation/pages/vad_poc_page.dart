/// vad_poc_page.dart
///
/// DEV-ONLY page for validating the VAD/utterance segmentation pipeline.
///
/// Pipeline under test:
///   Android Microphone
///     → RecordAudioRecorder (startStream, raw PCM int16 bytes)
///     → EnergyVad / MurojaahUtteranceSegmenter
///     → MurojaahAudioBuffer (finalized utterance)
///     → [optional manual] QuranOnnxRecognizer.transcribeSamples()
///     → MurojaahMatcher.match()
///
/// ASR is NOT invoked automatically. The user must tap "Run ASR" manually
/// after an utterance is finalized, to validate segmentation independently.
///
/// Do NOT modify MurojaahController.
/// Do NOT use this page as a template for production Murojaah UI.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../domain/murojaah_matcher.dart';
import '../../infrastructure/asr/quran_asr_result.dart';
import '../../infrastructure/asr/quran_onnx_recognizer.dart';
import '../../infrastructure/audio/murojaah_audio_recorder.dart';
import '../../infrastructure/audio/murojaah_utterance_segmenter.dart';

// ---------------------------------------------------------------------------
// Reference verse (for optional ASR validation)
// ---------------------------------------------------------------------------
const String _yasin001 = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ يسٓ';

// ---------------------------------------------------------------------------
// Page state
// ---------------------------------------------------------------------------

enum _PageState { idle, recording, error }

// ---------------------------------------------------------------------------
// Data model for finalized utterances
// ---------------------------------------------------------------------------

class _FinalizedUtterance {
  final int index;
  final MurojaahAudioBuffer buffer;
  AsrInferenceResult? asrResult;
  MurojaahMatchResult? matchResult;
  bool runningAsr = false;
  String? asrError;

  _FinalizedUtterance({required this.index, required this.buffer});

  String get label => 'Utterance #$index';
}

// ---------------------------------------------------------------------------
// StreamingRecorder — wraps AudioRecorder to expose live PCM byte stream
// ---------------------------------------------------------------------------
//
// RecordAudioRecorder collects PCM chunks internally and only exposes them
// via stop(). For the VAD POC we need the live stream.  Rather than modifying
// RecordAudioRecorder (which would break existing tests), we use the
// underlying `record` package AudioRecorder directly here, matching the same
// config RecordAudioRecorder uses.
//
// This is acceptable for a DEV-ONLY POC page.

class _StreamingRecorder {
  static const int _sampleRate = 16000;
  static const int _channels = 1;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  bool _recording = false;

  bool get isRecording => _recording;

  Future<bool> requestPermission() => _recorder.hasPermission();

  Future<void> start({required void Function(Uint8List) onChunk}) async {
    if (_recording) return;
    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: _channels,
      androidConfig: AndroidRecordConfig(
        audioSource: AndroidAudioSource.voiceRecognition,
      ),
    );
    final stream = await _recorder.startStream(config);
    _sub = stream.listen(
      onChunk,
      onError: (Object e) {
        // ignore: avoid_print
        debugPrint('[VadPocPage] stream error: $e');
      },
    );
    _recording = true;
  }

  Future<void> stop() async {
    if (!_recording) return;
    await _recorder.stop();
    await _sub?.cancel();
    _sub = null;
    _recording = false;
  }

  Future<void> dispose() async {
    await stop();
    _recorder.dispose();
  }
}

// ---------------------------------------------------------------------------
// Page widget
// ---------------------------------------------------------------------------

class VadPocPage extends StatefulWidget {
  /// Inject a [MurojaahAudioRecorder] for widget tests.
  ///
  /// When provided, the page uses a simplified record-then-feed mode instead
  /// of the live streaming path (since FakeAudioRecorder does not stream).
  /// Pass `null` (default) for real device use — uses [_StreamingRecorder].
  const VadPocPage({super.key, this.recorder});

  /// Optional injectable recorder. Used only in tests.
  final MurojaahAudioRecorder? recorder;

  @override
  State<VadPocPage> createState() => _VadPocPageState();
}

class _VadPocPageState extends State<VadPocPage> {
  // Streaming recorder for real device (live VAD feed).
  final _StreamingRecorder _streamRecorder = _StreamingRecorder();

  // VAD + segmenter — constructed with default config.
  final VadConfig _vadConfig = const VadConfig();
  late final MurojaahUtteranceSegmenter _segmenter;

  // ONNX engine — lazy-loaded on first "Run ASR" tap.
  final QuranOnnxRecognizer _engine = QuranOnnxRecognizer();

  // Page state.
  _PageState _pageState = _PageState.idle;
  String? _errorMessage;
  bool _permissionGranted = false;

  // Live diagnostics (updated on every VAD frame via setState throttle).
  double _liveRms = 0.0;
  double _livePeak = 0.0;
  bool _liveSpeech = false;
  double _liveUtteranceDuration = 0.0;
  int _liveTotalSamples = 0;
  SegmenterState _liveSegmenterState = SegmenterState.idle;

  // Finalized utterances (most recent at top).
  final List<_FinalizedUtterance> _utterances = [];

  // Throttle setState for diagnostics — avoid rebuilding on every PCM chunk.
  DateTime _lastDiagnosticsUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  static const _diagnosticsIntervalMs = 80; // ~12 Hz

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _segmenter = MurojaahUtteranceSegmenter(config: _vadConfig);
    _initPermission();
  }

  Future<void> _initPermission() async {
    try {
      final granted = widget.recorder != null
          // Test mode: use injected recorder for permission check.
          ? await widget.recorder!.requestPermission()
          : await _streamRecorder.requestPermission();
      if (mounted) {
        setState(() {
          _permissionGranted = granted;
          if (!granted) {
            _pageState = _PageState.error;
            _errorMessage =
                'Microphone permission denied. Grant access in device settings.';
          }
        });
      }
      // Also initialize injected recorder if provided.
      if (widget.recorder != null && granted) {
        await widget.recorder!.initialize();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pageState = _PageState.error;
          _errorMessage = 'Permission check failed: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _streamRecorder.dispose();
    _engine.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Recording control
  // ---------------------------------------------------------------------------

  Future<void> _start() async {
    if (_pageState == _PageState.recording) return;
    if (!_permissionGranted) {
      setState(() {
        _pageState = _PageState.error;
        _errorMessage = 'Microphone permission not granted.';
      });
      return;
    }

    setState(() {
      _pageState = _PageState.recording;
      _errorMessage = null;
    });

    _segmenter.reset();

    try {
      if (widget.recorder != null) {
        // Test / fake mode: start the injected recorder and stop immediately
        // to get the fake buffer, then feed it through the segmenter.
        await widget.recorder!.start();
        final buf = await widget.recorder!.stop();
        _segmenter.addSamples(buf.samples);
        _checkForCompletedUtterance();
        if (mounted) setState(() => _pageState = _PageState.idle);
      } else {
        // Real device: start streaming live PCM to segmenter.
        await _streamRecorder.start(
          onChunk: (Uint8List bytes) {
            _segmenter.addBytes(bytes);
            _checkForCompletedUtterance();
            _throttledDiagnosticsUpdate();
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pageState = _PageState.error;
          _errorMessage = 'Start failed: $e';
        });
      }
    }
  }

  Future<void> _stop() async {
    if (_pageState != _PageState.recording) return;
    try {
      if (widget.recorder == null) {
        await _streamRecorder.stop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Stop error: $e';
        });
      }
    }
    if (mounted) {
      setState(() => _pageState = _PageState.idle);
    }
  }

  void _clear() {
    _segmenter.reset();
    setState(() {
      _utterances.clear();
      _liveRms = 0.0;
      _livePeak = 0.0;
      _liveSpeech = false;
      _liveUtteranceDuration = 0.0;
      _liveTotalSamples = 0;
      _liveSegmenterState = SegmenterState.idle;
      _errorMessage = null;
      _pageState = _PageState.idle;
    });
  }

  // ---------------------------------------------------------------------------
  // Segmenter polling
  // ---------------------------------------------------------------------------

  void _checkForCompletedUtterance() {
    final buf = _segmenter.consumeCompletedUtterance();
    if (buf != null) {
      final utterance = _FinalizedUtterance(
        index: _utterances.length + 1,
        buffer: buf,
      );
      if (mounted) {
        setState(() {
          _utterances.insert(0, utterance); // most recent first
          _syncDiagnostics();
        });
      }
    }
  }

  void _throttledDiagnosticsUpdate() {
    final now = DateTime.now();
    if (now.difference(_lastDiagnosticsUpdate).inMilliseconds <
        _diagnosticsIntervalMs)
      return;
    _lastDiagnosticsUpdate = now;
    if (mounted) {
      setState(_syncDiagnostics);
    }
  }

  void _syncDiagnostics() {
    _liveRms = _segmenter.currentRms;
    _livePeak = _segmenter.currentPeak;
    _liveSpeech = _segmenter.isSpeechDetected;
    _liveUtteranceDuration = _segmenter.currentUtteranceDurationSeconds;
    _liveTotalSamples = _segmenter.totalSamples;
    _liveSegmenterState = _segmenter.state;
  }

  // ---------------------------------------------------------------------------
  // ASR (manual, on finalized utterance only)
  // ---------------------------------------------------------------------------

  Future<void> _runAsr(_FinalizedUtterance utterance) async {
    if (utterance.runningAsr) return;
    setState(() {
      utterance.runningAsr = true;
      utterance.asrResult = null;
      utterance.matchResult = null;
      utterance.asrError = null;
    });
    try {
      final result = await _engine.transcribeSamples(
        utterance.buffer.samples,
        durationSeconds: utterance.buffer.durationSeconds,
      );
      final match = MurojaahMatcher.match(_yasin001, result.transcript);
      if (mounted) {
        setState(() {
          utterance.asrResult = result;
          utterance.matchResult = match;
          utterance.runningAsr = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          utterance.asrError = 'ASR failed: $e';
          utterance.runningAsr = false;
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
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        title: const Text(
          '[DEV] Murojaah VAD POC',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(),
          const SizedBox(height: 12),
          _buildDiagnosticsCard(),
          const SizedBox(height: 12),
          _buildControlsCard(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _buildErrorCard(),
          ],
          if (_utterances.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildUtterancesCard(),
          ],
          const SizedBox(height: 24),
          _buildConfigCard(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status card
  // ---------------------------------------------------------------------------

  Widget _buildStatusCard() {
    final (label, color) = switch (_pageState) {
      _PageState.idle => switch (_liveSegmenterState) {
        SegmenterState.idle => ('IDLE', Colors.grey.shade600),
        SegmenterState.speaking => ('SPEAKING', Colors.green.shade700),
        SegmenterState.utteranceReady => (
          'UTTERANCE READY',
          Colors.blue.shade700,
        ),
      },
      _PageState.recording => switch (_liveSegmenterState) {
        SegmenterState.idle => ('RECORDING — IDLE', Colors.orange.shade700),
        SegmenterState.speaking => (
          'RECORDING — SPEAKING',
          Colors.green.shade700,
        ),
        SegmenterState.utteranceReady => (
          'UTTERANCE READY',
          Colors.blue.shade700,
        ),
      },
      _PageState.error => ('ERROR', Colors.red.shade700),
    };

    return _card(
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            'Status: $label',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Diagnostics card
  // ---------------------------------------------------------------------------

  Widget _buildDiagnosticsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _monoLabel('LIVE DIAGNOSTICS', Colors.grey.shade700),
          const SizedBox(height: 8),
          _diagRow('RMS', _liveRms.toStringAsFixed(4)),
          _diagRow('Peak', _livePeak.toStringAsFixed(4)),
          _diagRow(
            'Speech',
            _liveSpeech ? 'YES' : 'NO',
            valueColor: _liveSpeech
                ? Colors.green.shade700
                : Colors.grey.shade600,
          ),
          _diagRow(
            'Utterance dur',
            _liveSegmenterState == SegmenterState.speaking
                ? '${_liveUtteranceDuration.toStringAsFixed(2)}s'
                : '—',
          ),
          _diagRow('Total samples', '$_liveTotalSamples'),
          _diagRow(
            'Finalized utterances',
            '${_segmenter.finalizedUtteranceCount}',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Controls card
  // ---------------------------------------------------------------------------

  Widget _buildControlsCard() {
    final isRecording = _pageState == _PageState.recording;
    final canStart =
        !isRecording && _pageState != _PageState.error && _permissionGranted;
    final canStop = isRecording;

    return _card(
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: canStart ? _start : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
              ),
              child: const Text('Start'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: canStop ? _stop : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: const Text('Stop'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _clear,
              child: const Text('Clear'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error card
  // ---------------------------------------------------------------------------

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Text(
        _errorMessage ?? '',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Colors.red.shade800,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Finalized utterances card
  // ---------------------------------------------------------------------------

  Widget _buildUtterancesCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _monoLabel('FINALIZED UTTERANCES', Colors.grey.shade700),
          const SizedBox(height: 8),
          ..._utterances.map(_buildUtteranceRow),
        ],
      ),
    );
  }

  Widget _buildUtteranceRow(_FinalizedUtterance u) {
    final buf = u.buffer;
    final asr = u.asrResult;
    final match = u.matchResult;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            u.label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _diagRow('Duration', '${buf.durationSeconds.toStringAsFixed(2)}s'),
          _diagRow('Samples', '${buf.sampleCount}'),
          _diagRow('RMS', buf.rms.toStringAsFixed(4)),
          _diagRow('Peak', buf.peak.toStringAsFixed(4)),
          _diagRow('Silence', '${buf.silencePercentage.toStringAsFixed(1)}%'),
          const SizedBox(height: 8),
          // ASR section
          if (u.runningAsr)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: LinearProgressIndicator(),
            )
          else if (asr != null) ...[
            _monoLabel('ASR RESULT', Colors.blue.shade700),
            const SizedBox(height: 4),
            _diagRow(
              'Transcript',
              asr.transcript.isEmpty ? '(empty)' : asr.transcript,
            ),
            if (match != null) ...[
              _diagRow(
                'Score',
                match.effectiveScore.toStringAsFixed(4),
                valueColor: match.decision == MurojaahDecision.accept
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),
              _diagRow(
                'Decision',
                match.decision.name.toUpperCase(),
                valueColor: match.decision == MurojaahDecision.accept
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            ],
          ] else if (u.asrError != null)
            Text(
              u.asrError!,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.red.shade700,
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _runAsr(u),
                child: const Text('Run ASR'),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Config card (read-only display)
  // ---------------------------------------------------------------------------

  Widget _buildConfigCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _monoLabel('VAD CONFIG', Colors.grey.shade700),
          const SizedBox(height: 8),
          _diagRow('Sample rate', '${_vadConfig.sampleRate} Hz'),
          _diagRow('Frame duration', '${_vadConfig.frameDurationMs} ms'),
          _diagRow('Speech threshold', _vadConfig.speechThreshold.toString()),
          _diagRow(
            'Consecutive speech frames',
            '${_vadConfig.consecutiveSpeechFrames} '
                '(${_vadConfig.consecutiveSpeechFrames * _vadConfig.frameDurationMs} ms)',
          ),
          _diagRow(
            'End silence',
            '${_vadConfig.consecutiveSilenceFrames} frames '
                '(${_vadConfig.endSilenceDurationMs} ms)',
          ),
          _diagRow('Pre-padding', '${_vadConfig.preSpeechPaddingMs} ms'),
          _diagRow('Post-padding', '${_vadConfig.postSpeechPaddingMs} ms'),
          _diagRow('Max utterance', '${_vadConfig.maxUtteranceDurationMs} ms'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared UI helpers
  // ---------------------------------------------------------------------------

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _monoLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _diagRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
