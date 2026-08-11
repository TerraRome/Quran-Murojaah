# Quran ASR Models

Candidates and references for the Murojaah ASR Proof of Concept.

> **Important:** Do not select a model based solely on published benchmarks.
> All candidates must eventually be tested using real Quran recitation recorded from the intended user/device.

---

## 1. Quran FastConformer

### Muno459 FastConformer Quran

Hugging Face:

https://huggingface.co/Muno459/fastconformer-quran

- Quran-specific
- FastConformer
- Automatic Speech Recognition
- Designed for Quranic recitation
- Full-utterance/offline model
- Streaming variant available separately
- Candidate for high-accuracy Quran recognition
- Also includes mispronunciation-related research

The model card reports a leakage-free held-out benchmark and provides separate information for offline and streaming models.

### Streaming Variant

https://huggingface.co/Muno459/fastconformer-quran-streaming

Use this candidate when realtime streaming becomes a priority.

### Mobile-oriented Alternative

https://huggingface.co/TheGreatQuran2026/fastconformer-quran-ar

This repository provides a quantized ONNX model described as mobile-ready, including an approximately 80 MB quantized ONNX file.

- Quran-specific
- FastConformer
- ONNX
- Quantized
- Streaming support
- Offline support
- Candidate for mobile deployment

---

## 2. Quran STT ONNX

### Saboorhsn Quran STT ONNX

Hugging Face:

https://huggingface.co/Saboorhsn/quran-stt-onnx

- Quran-specific
- ONNX
- Local inference
- Based on FastConformer Quran ASR
- Supports offline inference
- Provides streaming configurations
- Includes tokenizer and auxiliary files
- Candidate for mobile/local deployment

This repository is an ONNX export of:

```text
Muno459/fastconformer-quran
```

Therefore it should be considered primarily an **ONNX deployment/export path of the FastConformer model**, not an entirely separate ASR architecture.

The repository also documents:

- unified ONNX models
- split streaming models
- quantized models
- realtime streaming
- simplified inference
- hybrid scoring

---

## 3. Quran Fine-tuned Whisper

### Whisper Medium Arabic — Quran Fine-tuned

Hugging Face:

https://huggingface.co/yousifgamalo/quran-s-finetuned

- Quran-specific
- Arabic
- Whisper Medium
- Fine-tuned specifically for Quranic recitation
- Based on `openai/whisper-medium`
- Apache 2.0
- Good baseline for comparison
- Significantly heavier than small/mobile-oriented ASR candidates

Use this primarily as a **Whisper baseline** rather than assuming it is the best mobile model.

---

# Evaluation

Every model must eventually be tested using the same real Quran recitation samples.

| Model                     | Type                 | WER | Verse Accuracy | Latency | RAM | Offline | Mobile |
| ------------------------- | -------------------- | --: | -------------: | ------: | --: | ------- | ------ |
| Muno459 FastConformer     | FastConformer        | TBD |            TBD |     TBD | TBD | TBD     | TBD    |
| FastConformer Streaming   | FastConformer        | TBD |            TBD |     TBD | TBD | TBD     | TBD    |
| Quran STT ONNX            | ONNX / FastConformer | TBD |            TBD |     TBD | TBD | Yes     | TBD    |
| FastConformer Mobile ONNX | ONNX / Quantized     | TBD |            TBD |     TBD | TBD | Yes     | TBD    |
| Quran Fine-tuned Whisper  | Whisper Medium       | TBD |            TBD |     TBD | TBD | Yes     | TBD    |

---

# POC Priority

Do not test every candidate simultaneously.

Use this order:

### POC #1

```text
Quran STT ONNX
```

https://huggingface.co/Saboorhsn/quran-stt-onnx

Reason:

- ONNX
- local inference
- Quran-specific
- already intended for deployment
- suitable starting point for testing

### POC #2

If POC #1 is unsuitable:

```text
FastConformer Mobile ONNX
```

https://huggingface.co/TheGreatQuran2026/fastconformer-quran-ar

### POC #3

If additional comparison is required:

```text
Quran Fine-tuned Whisper
```

https://huggingface.co/yousifgamalo/quran-s-finetuned

### POC #4

If higher accuracy/offline comparison is required:

```text
Muno459 FastConformer Quran
```

https://huggingface.co/Muno459/fastconformer-quran

---

# Evaluation Rules

Use the same:

- audio recordings
- Quran verses
- audio format
- expected transcript
- hardware

for every model.

Measure at minimum:

- WER
- CER
- verse accuracy
- inference latency
- realtime factor
- RAM usage
- model size
- CPU usage

For realtime Murojaah, additionally measure:

- streaming latency
- partial transcript stability
- final transcript latency
- behavior during pauses
- behavior with different recitation speeds

---

# Important

Published benchmark numbers are useful for selecting candidates, but they are not sufficient for the final decision.

The final model must be selected based on:

```text
Accuracy
+
Realtime performance
+
Mobile feasibility
+
Memory usage
+
Model size
+
Offline capability
+
Real user recitation
```

Do not integrate any candidate into the Flutter application until the POC has been completed.
