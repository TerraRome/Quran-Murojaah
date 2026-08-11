/// token_decoder.dart
///
/// CTC greedy decoder + BPE detokeniser matching the Python POC pipeline.
///
/// Python reference (transcribe.py):
///   def decode_tokens(token_ids, id2tok):
///     # CTC collapse: remove blank (0) and consecutive duplicates
///     collapsed = []
///     prev = None
///     for t in token_ids:
///       if t != 0 and t != prev:
///         collapsed.append(t)
///       prev = t
///     # BPE join: map ids → pieces, join, replace ▁ with space
///     pieces = [id2tok.get(t, '') for t in collapsed]
///     text = ''.join(pieces).replace('▁', ' ').strip()
///     return text
library token_decoder;

/// Maps token IDs to their string pieces.
typedef Vocabulary = Map<int, String>;

/// CTC greedy decoder + BPE detokeniser.
class TokenDecoder {
  static const int _blankId = 0;

  /// BPE word-boundary marker used by the SentencePiece tokeniser.
  static const String _boundaryMarker = '▁';

  /// Build a [Vocabulary] from the tokenizer_vocab.json structure.
  ///
  /// Expected JSON format:
  /// ```json
  /// { "pieces": [ {"id": 0, "piece": "<unk>"}, ... ] }
  /// ```
  static Vocabulary buildVocabulary(Map<String, dynamic> json) {
    final pieces = json['pieces'] as List<dynamic>;
    final vocab = <int, String>{};
    for (final entry in pieces) {
      final id    = entry['id'] as int;
      final piece = entry['piece'] as String;
      vocab[id] = piece;
    }
    return vocab;
  }

  /// Decode a flat list of per-frame logits (shape: [T, vocabSize]) using
  /// CTC greedy search (argmax per frame), then detokenise with BPE.
  ///
  /// [logits] — flat row-major array of shape (T × vocabSize)
  /// [vocabSize] — number of vocabulary entries (1024 for this model)
  /// [vocab]     — id → piece mapping from [buildVocabulary]
  static String decodeLogits({
    required List<dynamic> logits,
    required int vocabSize,
    required Vocabulary vocab,
  }) {
    final int nFrames = logits.length ~/ vocabSize;
    final tokenIds = List<int>.filled(nFrames, 0);

    for (int t = 0; t < nFrames; t++) {
      int bestId = 0;
      double bestVal = -double.infinity;
      final int offset = t * vocabSize;
      for (int v = 0; v < vocabSize; v++) {
        final double val = (logits[offset + v] as num).toDouble();
        if (val > bestVal) {
          bestVal = val;
          bestId = v;
        }
      }
      tokenIds[t] = bestId;
    }

    return decodeIds(tokenIds: tokenIds, vocab: vocab);
  }

  /// Collapse CTC token ID sequence and detokenise.
  ///
  /// Steps:
  ///   1. Remove blank tokens (id == 0)
  ///   2. Remove consecutive duplicates
  ///   3. Map ids → pieces via [vocab]
  ///   4. Join pieces, replace ▁ with space, strip leading/trailing whitespace
  static String decodeIds({
    required List<int> tokenIds,
    required Vocabulary vocab,
  }) {
    // Step 1 & 2: CTC collapse
    final collapsed = <int>[];
    int? prev;
    for (final id in tokenIds) {
      if (id != _blankId && id != prev) {
        collapsed.add(id);
      }
      prev = id;
    }

    // Step 3 & 4: BPE join
    final buffer = StringBuffer();
    for (final id in collapsed) {
      buffer.write(vocab[id] ?? '');
    }

    return buffer
        .toString()
        .replaceAll(_boundaryMarker, ' ')
        .trim();
  }
}
