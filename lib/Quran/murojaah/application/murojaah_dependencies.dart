/// murojaah_dependencies.dart
///
/// Session factory for the on-device ASR pipeline.
///
/// [buildMurojaahSession] always returns a fully wired
/// [MurojaahRecitationSession]. The caller owns the session lifecycle
/// (stop + dispose).
library murojaah_dependencies;

import '../infrastructure/asr/quran_onnx_recognizer.dart';
import '../infrastructure/audio/murojaah_utterance_segmenter.dart';
import '../infrastructure/audio/streaming_record_audio_recorder.dart';
import 'murojaah_recitation_session.dart';

// ---------------------------------------------------------------------------
// Session factory
// ---------------------------------------------------------------------------

/// Builds a fully wired [MurojaahRecitationSession] using production
/// components.
///
/// The caller is responsible for calling [MurojaahRecitationSession.stop]
/// and [MurojaahRecitationSession.dispose] when the session is no longer
/// needed. See [MurojaahPageShell] for the canonical ownership pattern.
///
/// Construction is cheap — [QuranOnnxRecognizer] loads the ONNX model
/// lazily on first inference, not on construction.
MurojaahRecitationSession buildMurojaahSession() {
  return MurojaahRecitationSession(
    recorder: StreamingRecordAudioRecorder(),
    segmenter: MurojaahUtteranceSegmenter(),
    asrEngine: QuranOnnxRecognizer(),
  );
}
