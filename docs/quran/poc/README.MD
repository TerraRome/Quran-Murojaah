# Murojaah ASR POC

## Goal

Determine the most suitable Quran ASR model
before integrating ASR into Flutter.

## Test Audio

Use real Quran recitation recorded from the intended user.

Test:

- quiet environment
- noisy environment
- short verse
- long verse
- slow recitation
- normal recitation

## Models

1. Quran FastConformer
2. Quran STT ONNX
3. Quran Fine-tuned Whisper

## Output

For every model record:

- transcript
- WER
- CER
- verse accuracy
- latency
- RAM
- model size
- CPU usage

## Definition of Done

A model is selected only after comparing
all candidates using the same audio samples.
