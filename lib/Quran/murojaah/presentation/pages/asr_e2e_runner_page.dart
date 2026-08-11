/// asr_e2e_runner_page.dart
///
/// DEV-ONLY diagnostic page for end-to-end ONNX ASR validation on macOS.
///
/// Lifecycle:
///   Page opens → initialize QuranOnnxRecognizer once → run Yasin 001 →
///   run Yasin 011 → run Yasin 001 again (warm repeat) → dispose on exit.
///
/// Do NOT wire this page into production navigation or use it as a template
/// for production Murojaah UI.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/murojaah_matcher.dart';
import '../../infrastructure/asr/quran_asr_result.dart';
import '../../infrastructure/asr/quran_onnx_recognizer.dart';

// ---------------------------------------------------------------------------
// Reference verses — sourced from quran.json (surah 36, verses 1 and 11)
// ---------------------------------------------------------------------------

/// Yasin 001 arabic text as it appears in quran.json.
const String _yasin001 = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ يسٓ';

/// Yasin 011 arabic text as it appears in quran.json.
const String _yasin011 =
    'إِنَّمَا تُنذِرُ مَنِ ٱتَّبَعَ ٱلذِّكْرَ وَخَشِىَ ٱلرَّحْمَٰنَ '
    'بِٱلْغَيْبِ ۖ فَبَشِّرْهُ بِمَغْفِرَةٍۢ وَأَجْرٍۢ كَرِيمٍ';

// ---------------------------------------------------------------------------
// Data model for one test run result
// ---------------------------------------------------------------------------

class _RunResult {
  final String label;
  final String wavAsset;
  final String expectedArabic;
  final AsrInferenceResult? inference;
  final MurojaahMatchResult? match;
  final String? error;

  const _RunResult({
    required this.label,
    required this.wavAsset,
    required this.expectedArabic,
    this.inference,
    this.match,
    this.error,
  });
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class AsrE2eRunnerPage extends StatefulWidget {
  const AsrE2eRunnerPage({super.key});

  @override
  State<AsrE2eRunnerPage> createState() => _AsrE2eRunnerPageState();
}

class _AsrE2eRunnerPageState extends State<AsrE2eRunnerPage> {
  // Engine is created once and reused across all runs.
  final QuranOnnxRecognizer _engine = QuranOnnxRecognizer();

  _PageState _state = _PageState.idle;
  String _statusMessage = 'Ready. Tap "Run E2E" to start.';
  int _modelLoadMs = 0;
  final List<_RunResult> _results = [];

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Run sequence
  // -------------------------------------------------------------------------

  Future<void> _runAll() async {
    setState(() {
      _state = _PageState.running;
      _statusMessage = 'Initializing ONNX session…';
      _results.clear();
      _modelLoadMs = 0;
    });

    try {
      // 1. Warm up engine — measures model load time
      final loadSw = Stopwatch()..start();
      await _engine.warmUp();
      loadSw.stop();
      _modelLoadMs = loadSw.elapsedMilliseconds;

      setState(() {
        _statusMessage =
            'Model loaded in ${_modelLoadMs}ms. Running Yasin 001…';
      });

      // 2. Define the ordered test suite
      final suite = [
        (
          label: 'Yasin 001 (first)',
          asset: 'docs/quran/murojaah/poc/samples/test_ayat1.wav',
          expected: _yasin001,
        ),
        (
          label: 'Yasin 011',
          asset: 'docs/quran/murojaah/poc/samples/ayat11.wav',
          expected: _yasin011,
        ),
        (
          label: 'Yasin 001 (warm repeat)',
          asset: 'docs/quran/murojaah/poc/samples/test_ayat1.wav',
          expected: _yasin001,
        ),
      ];

      // 3. Run each entry
      for (final entry in suite) {
        setState(() => _statusMessage = 'Running ${entry.label}…');

        _RunResult result;
        try {
          final wavBytes = await _loadWavAsset(entry.asset);
          final inference = await _engine.transcribeWav(wavBytes);
          final matchResult = MurojaahMatcher.match(
            entry.expected,
            inference.transcript,
          );
          result = _RunResult(
            label: entry.label,
            wavAsset: entry.asset,
            expectedArabic: entry.expected,
            inference: inference,
            match: matchResult,
          );
        } catch (e, st) {
          result = _RunResult(
            label: entry.label,
            wavAsset: entry.asset,
            expectedArabic: entry.expected,
            error: '$e\n$st',
          );
        }

        setState(() => _results.add(result));
      }

      setState(() {
        _state = _PageState.done;
        _statusMessage = 'Done. ${_results.length} runs completed.';
      });
    } catch (e, st) {
      setState(() {
        _state = _PageState.error;
        _statusMessage = 'Fatal error during setup:\n$e\n$st';
      });
    }
  }

  Future<Uint8List> _loadWavAsset(String assetKey) async {
    final byteData = await rootBundle.load(assetKey);
    return byteData.buffer.asUint8List();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('[DEV] ASR E2E Runner'),
        backgroundColor: Colors.deepOrange.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.all(12),
            child: Text(
              _statusMessage,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.greenAccent,
                fontSize: 12,
              ),
            ),
          ),

          // Model load timing
          if (_modelLoadMs > 0)
            Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'Model load: ${_modelLoadMs}ms',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.amber,
                  fontSize: 12,
                ),
              ),
            ),

          // Run button
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: _state == _PageState.running ? null : _runAll,
              icon: _state == _PageState.running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                _state == _PageState.running ? 'Running…' : 'Run E2E',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          // Results
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Text(
                      'No results yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(height: 24),
                    itemBuilder: (_, i) => _ResultCard(
                      result: _results[i],
                      modelLoadMs: _modelLoadMs,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result card widget
// ---------------------------------------------------------------------------

class _ResultCard extends StatelessWidget {
  final _RunResult result;
  final int modelLoadMs;

  const _ResultCard({required this.result, required this.modelLoadMs});

  @override
  Widget build(BuildContext context) {
    final inf = result.inference;
    final match = result.match;
    final hasError = result.error != null;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              result.label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),

            if (hasError) ...[
              _kv('Status', 'ERROR', valueColor: Colors.red),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade50,
                child: Text(
                  result.error!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Colors.red,
                  ),
                ),
              ),
            ] else if (inf != null && match != null) ...[
              // Audio
              _kv(
                'Audio duration',
                '${inf.audioDurationSeconds.toStringAsFixed(2)}s',
              ),

              // Timings
              _kv('Model load', '${modelLoadMs}ms (shared, measured once)'),
              _kv('Preprocessing', '${inf.timings.preprocessMs}ms'),
              _kv('ONNX inference', '${inf.timings.inferenceMs}ms'),
              _kv('CTC decode', '${inf.timings.decodeMs}ms'),
              _kv('Total (excl. load)', '${inf.timings.totalMs}ms'),
              _kv(
                'RTF (inference only)',
                inf.realtimeFactor.toStringAsFixed(4),
              ),
              _kv(
                'RTF (full pipeline)',
                inf.fullRealtimeFactor.toStringAsFixed(4),
              ),

              const Divider(height: 16),

              // Expected text
              _label('Expected (quran.json):'),
              _arabicText(result.expectedArabic),

              const SizedBox(height: 6),

              // Raw transcript
              _label('Raw transcript:'),
              _arabicText(
                inf.transcript.isEmpty ? '(empty)' : inf.transcript,
                color: inf.transcript.isEmpty ? Colors.red : null,
              ),

              const SizedBox(height: 6),

              // Matcher
              _kv('Matcher score', match.effectiveScore.toStringAsFixed(4)),
              _kv(
                'Decision',
                match.decision.name.toUpperCase(),
                valueColor: _decisionColor(match.decision),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String key, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              '$key:',
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
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: 'monospace',
      fontSize: 11,
      color: Colors.black54,
    ),
  );

  Widget _arabicText(String text, {Color? color}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      textDirection: TextDirection.rtl,
      style: TextStyle(fontSize: 16, height: 1.8, color: color),
    ),
  );

  Color _decisionColor(MurojaahDecision decision) {
    return switch (decision) {
      MurojaahDecision.accept => Colors.green.shade700,
      MurojaahDecision.retry => Colors.orange.shade700,
      MurojaahDecision.reject => Colors.red.shade700,
    };
  }
}

// ---------------------------------------------------------------------------
// Page state enum
// ---------------------------------------------------------------------------

enum _PageState { idle, running, done, error }
