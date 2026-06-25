---
title: Voice Bank
summary: The opt-in local corpus of (audio, transcript) pairs that feeds voice cloning; explains storage, quality gate, selection heuristic, and corpus statistics.
topics: [voice-bank, decisions]
sources:
  - id: voice-bank-store
    type: file
    path: Sources/VoiceBank/VoiceBankStore.swift
    note: Core Data store for VoiceSampleEntry rows.
  - id: voice-sample
    type: file
    path: Sources/VoiceBank/VoiceSample.swift
    note: Entity definition with id, createdAt, audioFileName, transcript, durationMs, wordCount, appBundleId.
  - id: quality-gate
    type: file
    path: Sources/VoiceBank/VoiceBankQualityGate.swift
    note: Drops silent/too-short/non-dictation clips.
  - id: replay-tool
    type: file
    path: Tools/replay/main.swift
    note: SwiftPM regression harness; re-runs banked WAVs through transcription.
  - id: app-state-selection
    type: file
    path: Sources/AppState.swift
    note: selectedVoiceCloneSamples() — clip selection algorithm for clone upload.
---

# Voice Bank

The Voice Bank is the opt-in local dataset of `(audio, transcript)` pairs that feeds voice
cloning ([[voice-cloning]]). It is new in this fork — upstream freeflow recorded audio to a temp
file and **deleted** it after transcription, keeping only a capped run-log. None of
`Sources/VoiceBank/` exists upstream.

## Behavior
- Off by default. The toggle persists under UserDefaults key `voiceBankEnabled`. With it off,
  the app behaves exactly like upstream freeflow (nothing extra stored) — this default preserves
  freeflow's "no server, no retained data" promise and keeps the fork upstream-mergeable.
- When on, after a successful dictation the normalized 16 kHz WAV is copied (not deleted) into
  `~/Library/Application Support/Whispr Free Me Dev/VoiceBank/<uuid>.wav`, and a `VoiceSample`
  row (id, createdAt, audioFileName, transcript, durationMs, wordCount, appBundleId) is inserted
  via [[Sources/VoiceBank/VoiceBankStore.swift]] (its own Core Data SQLite store, decoupled from
  the capped pipeline history so banked data is never trimmed away).
- A quality gate ([[Sources/VoiceBank/VoiceBankQualityGate.swift]]) drops silent/too-short/failed
  clips and keeps only `dictation` intent.
- Settings → Voice Bank lists samples with a ▶ play button (reuses the run-log `AudioPlayerView`
  that already existed upstream), plus delete/clear.

## Decision: label with the RAW transcript
Samples are labelled with the **raw** transcript (what Whisper produced), not the
post-processed/cleaned text. Cleanup removes filler and applies edits, so the cleaned text does
not match the audio; voice/STT training needs transcript == audio.

## Replay harness — regression testing on real audio
[[Tools/replay/main.swift]] is a SwiftPM executable (`swift run replay <dir>`, needs
`GROQ_API_KEY`) that re-runs banked WAVs through the real transcription endpoint + the
`HallucinationFilter`, printing raw vs cleaned. It was built to verify the okay-hallucination fix
on the user's actual clips, and is the project's regression tester for transcription changes.

## Corpus snapshot (as of 2026-06-22)

After 14 days of normal dictation use (Jun 9–Jun 22), the bank held:

| Metric | Value |
|---|---|
| Clips | 350 WAVs |
| Total duration | 73.0 min |
| Words (raw transcript) | 11,624 |
| Avg clip length | 12.5 s |
| Disk | 139 MB (16 kHz WAV) |

**Source app breakdown** (where the user was dictating):

| App bundle ID | Clips |
|---|---|
| com.anthropic.claudefordesktop | 263 |
| com.openai.chat | 47 |
| com.apple.MobileSMS | 26 |
| com.apple.Safari | 10 |
| com.google.Chrome | 4 |

Confirmed via `sqlite3 VoiceBank.sqlite` on `ZVOICESAMPLEENTRY` — the store and on-disk WAVs agreed. The quality gate had already filtered silent/too-short/non-dictation clips; these 350 are the kept ones.

**For voice cloning context:** ElevenLabs Instant Voice Cloning uses only ~5 minutes as a reference and ignores the rest. At 73 min, the bank is past the saturation point for instant cloning and well into the range for **fine-tuning / Professional Voice Cloning** approaches. See [[voice-cloning]] for selection algorithm and provider alternatives.
