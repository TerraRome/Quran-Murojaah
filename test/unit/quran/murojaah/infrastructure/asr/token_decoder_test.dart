/// token_decoder_test.dart
///
/// Unit tests for TokenDecoder (CTC greedy decode + BPE detokenisation).
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_portfolio/Quran/murojaah/infrastructure/asr/token_decoder.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a minimal vocab from a list of (id, piece) pairs.
Vocabulary _vocab(List<(int, String)> entries) {
  return {for (final (id, piece) in entries) id: piece};
}

/// Build flat logits list for T frames × V vocab where frame [t] has argmax at [tokenId].
List<double> _oneHotLogits({
  required List<int> tokenIds,
  required int vocabSize,
}) {
  final logits = List<double>.filled(tokenIds.length * vocabSize, -10.0);
  for (int t = 0; t < tokenIds.length; t++) {
    logits[t * vocabSize + tokenIds[t]] = 10.0;
  }
  return logits;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TokenDecoder.buildVocabulary', () {
    test('parses pieces list correctly', () {
      final json = {
        'vocab_size': 4,
        'pieces': [
          {'id': 0, 'piece': '<unk>', 'score': 0.0},
          {'id': 1, 'piece': 'ا', 'score': -1.0},
          {'id': 2, 'piece': 'ب', 'score': -2.0},
          {'id': 3, 'piece': '▁ج', 'score': -3.0},
        ],
      };
      final vocab = TokenDecoder.buildVocabulary(json);
      expect(vocab[0], equals('<unk>'));
      expect(vocab[1], equals('ا'));
      expect(vocab[2], equals('ب'));
      expect(vocab[3], equals('▁ج'));
    });

    test('handles empty pieces list', () {
      final vocab = TokenDecoder.buildVocabulary({'pieces': []});
      expect(vocab, isEmpty);
    });
  });

  group('TokenDecoder.decodeIds — CTC collapse', () {
    test('removes blank token (id=0)', () {
      final vocab = _vocab([(0, '<unk>'), (1, 'ا'), (2, 'ب')]);
      final result = TokenDecoder.decodeIds(
        tokenIds: [0, 1, 0, 2, 0],
        vocab: vocab,
      );
      expect(result, equals('اب'));
    });

    test('removes consecutive duplicates', () {
      final vocab = _vocab([(0, '<unk>'), (1, 'ا'), (2, 'ب')]);
      final result = TokenDecoder.decodeIds(
        tokenIds: [1, 1, 1, 2, 2, 1],
        vocab: vocab,
      );
      expect(result, equals('اباب'.substring(0, 3))); // ا ب ا
    });

    test('all blanks returns empty string', () {
      final vocab = _vocab([(0, '<unk>')]);
      final result = TokenDecoder.decodeIds(tokenIds: [0, 0, 0], vocab: vocab);
      expect(result, equals(''));
    });

    test('empty token list returns empty string', () {
      final vocab = _vocab([(0, '<unk>')]);
      final result = TokenDecoder.decodeIds(tokenIds: [], vocab: vocab);
      expect(result, equals(''));
    });

    test('unknown id maps to empty string (missing from vocab)', () {
      final vocab = _vocab([(0, '<unk>'), (1, 'ا')]);
      final result = TokenDecoder.decodeIds(tokenIds: [1, 999], vocab: vocab);
      expect(result, equals('ا')); // 999 → '' silently
    });
  });

  group('TokenDecoder.decodeIds — BPE boundary marker', () {
    test('replaces ▁ with space', () {
      final vocab = _vocab([
        (0, '<unk>'),
        (1, 'بِسْمِ'),
        (2, '▁اللَّهِ'),
        (3, '▁الرَّحْمَٰنِ'),
      ]);
      final result = TokenDecoder.decodeIds(
        tokenIds: [1, 2, 3],
        vocab: vocab,
      );
      expect(result, equals('بِسْمِ اللَّهِ الرَّحْمَٰنِ'));
    });

    test('strips leading/trailing whitespace', () {
      final vocab = _vocab([
        (0, '<unk>'),
        (1, '▁hello'),
        (2, '▁world'),
      ]);
      final result = TokenDecoder.decodeIds(tokenIds: [1, 2], vocab: vocab);
      expect(result, equals('hello world'));
    });
  });

  group('TokenDecoder.decodeLogits', () {
    test('argmax selects correct token per frame', () {
      const int vocabSize = 5;
      final vocab = _vocab([
        (0, '<unk>'),
        (1, 'ا'),
        (2, 'ب'),
        (3, '▁ج'),
        (4, 'د'),
      ]);

      // frames: blank, ا, blank, ب, ▁ج
      final logits = _oneHotLogits(
        tokenIds: [0, 1, 0, 2, 3],
        vocabSize: vocabSize,
      );

      final result = TokenDecoder.decodeLogits(
        logits: logits,
        vocabSize: vocabSize,
        vocab: vocab,
      );
      // CTC collapse: 0→skip, 1→ا, 0→skip, 2→ب, 3→▁ج
      // BPE join: ا + ب + ▁ج → اب ج → strip → اب ج
      expect(result, equals('اب ج'));
    });

    test('repeated same token collapsed to one', () {
      const int vocabSize = 3;
      final vocab = _vocab([(0, '<unk>'), (1, 'ا'), (2, 'ب')]);

      // 5 frames all argmax = 1 → should collapse to single ا
      final logits = _oneHotLogits(
        tokenIds: [1, 1, 1, 1, 1],
        vocabSize: vocabSize,
      );

      final result = TokenDecoder.decodeLogits(
        logits: logits,
        vocabSize: vocabSize,
        vocab: vocab,
      );
      expect(result, equals('ا'));
    });

    test('all blank frames returns empty string', () {
      const int vocabSize = 3;
      final vocab = _vocab([(0, '<unk>'), (1, 'ا'), (2, 'ب')]);
      final logits = _oneHotLogits(
        tokenIds: [0, 0, 0],
        vocabSize: vocabSize,
      );
      final result = TokenDecoder.decodeLogits(
        logits: logits,
        vocabSize: vocabSize,
        vocab: vocab,
      );
      expect(result, equals(''));
    });
  });
}
