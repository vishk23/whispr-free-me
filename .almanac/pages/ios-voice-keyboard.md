---
title: iOS voice keyboard
summary: Architecture decisions, platform constraints, and foundation code (Phases 1–2) for the planned Wispr-style iOS voice keyboard that reuses the macOS dictation pipeline.
topics: [voice-pipeline, decisions, build-and-signing]
sources:
  - id: spec
    type: file
    path: docs/superpowers/specs/2026-06-09-ios-voice-keyboard-design.md
    note: Design spec — architecture, constraints, IPC model, Live Activity, scope.
  - id: plan
    type: file
    path: docs/superpowers/plans/2026-06-09-ios-voice-keyboard.md
    note: Phased implementation plan (Phases 0–9); Phases 1–2 completed in-environment.
  - id: package-swift
    type: file
    path: Package.swift
    note: ios-keyboard-foundation branch adds Pipeline + IOSShared targets with platforms [macOS .v13, iOS .v17].
  - id: makefile
    type: file
    path: Makefile
    note: Excludes Sources/IOSShared/ from the flat swiftc glob (iOS-only glue must not enter the macOS app build).
  - id: cleanup-config
    type: file
    path: Sources/Pipeline/CleanupConfig.swift
    note: Injected value type bundling cleanup policy so iOS and macOS feed the pipeline identically.
  - id: post-processing
    type: file
    path: Sources/Pipeline/PostProcessingService.swift
    note: Made public on ios-keyboard-foundation for cross-module iOS consumption.
  - id: transcription-service
    type: file
    path: Sources/Pipeline/TranscriptionService.swift
    note: Made public on ios-keyboard-foundation; Foundation-only, no AppKit.
  - id: ios-shared-payload
    type: file
    path: Sources/IOSShared/DictationPayload.swift
    note: Result handoff struct (carries requestId) between containing app and keyboard extension.
  - id: ios-shared-snapshot
    type: file
    path: Sources/IOSShared/SessionSnapshot.swift
    note: Cross-process session state (DictationState enum + SessionSnapshot).
  - id: ios-shared-settings
    type: file
    path: Sources/IOSShared/SyncableSettings.swift
    note: Versioned, forward-tolerant settings Codable — keys aligned with macOS UserDefaults for future sync.
  - id: ios-shared-appgroup
    type: file
    path: Sources/IOSShared/AppGroup.swift
    note: Injectable UserDefaults wrapper for App Group id group.com.vishk23.whisprfreeme.
  - id: ios-shared-darwin
    type: file
    path: Sources/IOSShared/DarwinBridge.swift
    note: CFNotificationCenter post/observe helpers for app↔keyboard IPC.
  - id: ios-shared-names
    type: file
    path: Sources/IOSShared/DarwinNames.swift
    note: Darwin notification name constants shared across app targets.
status: active
verified: 2026-06-09
---

# iOS voice keyboard

A planned native **iOS voice keyboard** (Wispr Flow-style): tap a button in any app, speak, get
cleaned-up text inserted at the cursor — reusing [[whispr-free-me]]'s transcription + cleanup
pipeline. Design: [[docs/superpowers/specs/2026-06-09-ios-voice-keyboard-design.md]]; phased
implementation plan: [[docs/superpowers/plans/2026-06-09-ios-voice-keyboard.md]].

## Why the architecture is shaped this way (binding constraints)

- **An iOS keyboard extension cannot access the microphone** — even with Full Access. The mic is
  excluded from keyboard-extension capabilities; this is a hard platform rule, not a setting. So
  the *containing app* holds the mic and the keyboard is a thin front-end. Confirmed against Apple
  docs and how Wispr Flow ships (its "Start Flow" bounces to the app to open the mic session).
- **Keyboard extensions have a tiny memory budget** (tens of MB) → all audio capture, networking,
  and transcription run in the containing app, never in the extension.
- **Staying alive for the mic** requires the `audio` background mode, active only while an audio
  session is held. This is the "Full Flow Session": a time-boxed held-audio window so dictation
  repeats without relaunching the app. "Always on" vs "light on battery" is a real tension; the
  lever is the session auto-end timer (5/15/60 min / never) plus teardown on Low Power Mode.
- **IPC**: containing app ↔ keyboard ↔ Live Activity communicate over an **App Group** shared
  container + **Darwin notifications** (`CFNotificationCenter`). The keyboard signals start/stop;
  the backgrounded app records → transcribes → writes the result to the App Group → posts done;
  the keyboard inserts via `textDocumentProxy`.
- **Transcription is batch per-utterance** (record clip → Groq → cleanup → insert), reusing the
  existing pipeline as-is. Live-partial streaming was explicitly deferred (needs a streaming-ASR
  backend beyond batch Groq).
- **The #1 risk is launching the containing app from the keyboard** (and returning the user). The
  Live Activity (Dynamic Island) softens the "return" half. A 1–2 day on-device spike gates the
  build; the per-dictation app-bounce is the fallback.

## Foundation built so far (plan Phases 1–2 — the macOS-buildable part)

On branch **`ios-keyboard-foundation`** (not yet merged), built + two-stage-reviewed, `swift test`
**72 green**, macOS `make` build green:

- **Shared multiplatform `Pipeline` SPM target** ([[Package.swift]], now
  `platforms: [.macOS(.v13), .iOS(.v17)]`). The Foundation-only transcription + cleanup code moved
  into [[Sources/Pipeline/TranscriptionService.swift]], [[Sources/Pipeline/PostProcessingService.swift]],
  `LLMAPITransport.swift`, `ModelConfiguration.swift`, with a `public` API for the future iOS app;
  behavior-preserving.
- **`CleanupConfig`** ([[Sources/Pipeline/CleanupConfig.swift]]) — an injected value type bundling
  cleanup policy (system prompt + custom vocabulary + context prompt) so iOS and macOS feed the
  pipeline identically with no `UserDefaults` coupling inside the package. Plus an `LLMTransport`
  protocol seam for tests.
- **`IOSShared` SPM target** — cross-process glue: `DictationPayload` (result handoff, carries a
  `requestId`), `SessionSnapshot`/`DictationState`, `SyncableSettings` (versioned, forward-tolerant
  decode, keys aligned with the macOS app — `custom_vocabulary` / `custom_system_prompt` — for a
  future sync project), `AppGroup`/`SharedStore` (injectable `UserDefaults`, App Group id
  `group.com.vishk23.whisprfreeme`), [[Sources/IOSShared/DarwinNames.swift]],
  [[Sources/IOSShared/DarwinBridge.swift]].

### The dual-build trap (gotcha)
The macOS app is compiled flat by the [[Makefile]] (`find Sources -name '*.swift'`), NOT via SPM.
So a file in `Sources/Pipeline/` is built BOTH as the SPM `Pipeline` module (for `swift test`) AND
flat into the macOS app. Consequences:
- `import Transcription` inside `Sources/Pipeline/` is wrapped in `#if canImport(Transcription)` —
  in the flat macOS build there is no separate module, so the import must be conditional.
- `Sources/IOSShared/` is **excluded** from the Makefile glob (`-not -path 'Sources/IOSShared/*'`)
  — it is iOS-app-only glue; keeping it out of the macOS app avoids binary pollution and flat-build
  name collisions.

## What is NOT done (needs a Mac + Xcode + device + Apple Developer Program)
Plan Phase 0 (the launch/IPC spike — the gate) and Phases 3–9: the XcodeGen iOS project (app +
keyboard extension + Live Activity widget), the Flow Session engine (`AVAudioSession`), the keyboard
UI, the Live Activity, on-device QA, and App Store prep. None of that exists in the repo yet.

## Where the work lives (branch map, as of 2026-06-09)
- `ios-keyboard-foundation` — the Pipeline + IOSShared foundation above. Built in an isolated git
  worktree to avoid colliding with concurrent work on other branches; the worktree was removed
  afterward, the branch retained.
- `ios-voice-keyboard` — earlier branch; the initial Pipeline-extraction commit was merged from here
  into `fix/dictation-cold-start-safety-net` during development.
- `wip-casual-eval` — unrelated parked WIP (the `Tools/casual-eval` harness + `HallucinationFilter`
  tweaks) rescued from a git stash so nothing was lost.

Cloud sync / accounts (so the keyboard shares vocabulary, snippets, and the cloned voice with the
Mac app) is a deliberate *later* project; v1 of the keyboard is local-only. See the spec's non-goals.
