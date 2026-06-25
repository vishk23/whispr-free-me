---
title: Whispr Free Me — overview
topics: [voice-pipeline, ui, decisions]
files:
  - Sources/AppState.swift
  - Sources/AudioRecorder.swift
  - Sources/TranscriptionService.swift
  - Sources/PostProcessingService.swift
  - Sources/DashboardView.swift
  - docs/superpowers/specs/2026-06-08-whispr-free-me-design.md
---

# Whispr Free Me

Whispr Free Me is a fork of [zachlatta/freeflow](https://github.com/zachlatta/freeflow) — a
native macOS menu-bar dictation app (Swift + SwiftUI + AVFoundation). The fork turns the
one-way **voice → text** dictation tool into a **two-way voice tool**: it banks your voice
while you dictate, clones it in the cloud, and adds **text → your voice, anywhere**. It also
adds a usage dashboard and content-aware cleanup modes. Bundle id `com.vishk23.whisprfreeme.dev`,
display name "Whispr Free Me Dev". The full design lives in
[[docs/superpowers/specs/2026-06-08-whispr-free-me-design.md]].

## The dictation pipeline
Hold `Fn` (or tap the toggle shortcut) → record → transcribe → clean up → paste. Driven by
[[Sources/AppState.swift]]:

1. **Capture** — [[Sources/AudioRecorder.swift]] records a normalized **16 kHz mono PCM16 WAV**
   to a temp file via `AVCaptureSession`. The realtime path also emits 24 kHz PCM16 chunks.
   `AVCaptureSession` is rebuilt from scratch on every dictation (no persistent/warm session) — the
   first-press cold-start lag is accepted by design (see [[gotchas-and-decisions]] for the silence
   guards). The start cue ("Tink") fires **immediately on key-press** at the top of `startRecording()`
   — before the mic is live — so feedback is instant; the cold-start guards handle the case where the
   user speaks into the warmup gap. The background-audio duck is applied synchronously right after the
   Tink. `playAlertSound` events: start=Tink, stop=Pop, cancel=Funk, error=Sosumi.
2. **Transcribe** — [[Sources/Pipeline/TranscriptionService.swift]] uploads the WAV to an
   OpenAI-compatible endpoint (Groq by default, `whisper-large-v3-turbo`), `response_format=verbose_json`.
   `HallucinationFilter` (in [[Sources/Transcription/HallucinationFilter.swift]], a SwiftPM module)
   strips Whisper's trailing filler hallucinations and silent-clip garbage — see [[gotchas-and-decisions]].
3. **Context + modes** — [[Sources/AppContextService.swift]] reads the frontmost app, window
   title, the **selected text** (`kAXSelectedTextAttribute`, Accessibility), and optionally a
   screenshot. Content-aware modes (`DictationModes`, in the `DictationModeKit` SwiftPM module at
   [[Sources/DictationModes/DictationModes.swift]]) map the frontmost app's bundle id → a cleanup
   style (Mail→formal, Xcode/Terminal→code, Messages/Slack→casual, else standard) injected into
   the cleanup prompt. See [[dictation-modes]] for routing rules, the casual register, and the eval
   harness.
4. **Clean up** — [[Sources/PostProcessingService.swift]] sends raw transcript + context + custom
   vocabulary to a cleanup LLM (default `openai/gpt-oss-120b` on Groq) and returns polished text,
   which is pasted.

Per-dictation records (raw + cleaned transcript, timestamp, app/window, intent) persist in a
Core Data SQLite store ([[Sources/PipelineHistoryStore.swift]]) and are capped (trimmed).

## Voice Bank
The opt-in training dataset — see [[voice-bank]]. New in this fork; absent in upstream freeflow.

## Dashboard
A native SwiftUI `NSWindow` opened from the menu bar ([[Sources/DashboardView.swift]],
[[Sources/DashboardMetrics.swift]]), mirroring how `AppDelegate.handleShowSettings` builds the
settings window. Tabs: **Stats** (dictations, words, time saved, streak, WPM, minutes banked,
14-day activity chart via Swift Charts, top apps), **Dictionary** (edits `AppState.customVocabulary`),
**Snippets** (edits `AppState.voiceMacros`, reusing the existing macro editor), **Voice Clone**,
and **Speak**. Reads `appState.pipelineHistory` + `voiceBankStats()` + `voiceBankSamples()`.

## Voice clone + speak-as-me
ElevenLabs integration — see [[voice-cloning]].

## iOS voice keyboard (planned)
A Wispr Flow-style iOS custom keyboard that reuses this app's transcription and cleanup pipeline.
The containing app holds the mic (keyboard extensions cannot); the keyboard extension is a thin
front-end communicating via App Group + Darwin notifications. A Live Activity (Dynamic Island)
surfaces the session. Transcription is batch per-utterance via the existing Groq pipeline.
Cloud sync and accounts are deliberately deferred to a later project; v1 is local-only. The
shared `Pipeline` + `IOSShared` SPM foundation (Phases 1–2 of the plan) is built and reviewed
on branch `ios-keyboard-foundation` (72 tests green). See [[ios-voice-keyboard]] for constraints,
IPC design, branch map, and what remains (needs Xcode + physical device + Apple Developer Program).

## Build, signing, gotchas
See [[gotchas-and-decisions]] for code signing, the okay-hallucination fix, the cold-start silence
guards (`capturedAudioWasSilent` / `isSilentClipFiller`), the honest start cue and cue-before-duck
fix, the ElevenLabs free-tier wall, AirPods audio ducking, the `make` staleness trap, and the
soft-prompt-suffix pattern (mode snippets that conflict with base-prompt rules lose). See
[[dictation-modes]] for the four cleanup modes, the casual register, and the eval harness.
