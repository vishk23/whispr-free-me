# iOS Voice Keyboard — Design

- **Date:** 2026-06-09
- **Status:** Approved (Phase 4, v1 scope); implementation plan to follow
- **Parent:** [Whispr Free Me — Design](2026-06-08-whispr-free-me-design.md) (this is a new platform target on the same product)
- **Working names:** not final (rename is cheap)

## 1. Summary

A native **iOS voice keyboard** modeled on the Wispr Flow iPhone keyboard: a third-party
keyboard you can switch to in any app, where you tap a button, speak, and have cleaned-up text
inserted at the cursor. Same transcription + cleanup pipeline as the macOS app, on the phone.

This is the first of three independent sub-projects the user scoped (keyboard → backend →
sync). **This spec covers the standalone keyboard only.** A cloud backend, accounts, and
Mac↔iOS sync (including cloud-stored cloned voices and off-device voice-bank storage) are
deliberately later, separate specs. The keyboard ships first because it is both the headline
feature and the riskiest piece (the iOS keyboard-extension mic limitation and App Review),
so it is worth de-risking before any infrastructure is built.

## 2. Background: the platform constraints that shape everything

Established by research against current iOS (see §10 for sources):

- **An iOS keyboard extension cannot access the microphone.** Even with "Full Access"
  enabled, the mic is excluded from what keyboards may use — it is a hard platform
  restriction, not a setting. The only sanctioned architecture for a "voice keyboard" is the
  one Wispr Flow uses: the **containing app** holds the mic; the keyboard is a front-end.
- **Keyboard extensions have a very tight memory budget** (tens of MB; the OS kills the
  extension above it). Audio capture, networking, and transcription must therefore run in the
  containing app, never in the extension.
- **Full Access** (`RequestsOpenAccess = YES`) is required for the keyboard to use the
  network policy and to share data with the containing app via an **App Group**.
- **Staying alive for the mic** requires the **audio background mode**
  (`UIBackgroundModes: [audio]`), which keeps the app running only while it holds an active
  audio session. This is exactly what a Wispr "Flow Session" is: a time-boxed window during
  which the app holds the mic, so the keyboard can dictate repeatedly without relaunching the
  app each time.
- **Distribution differs from the Mac app.** The macOS app ships as a direct DMG. A keyboard
  must go through the App Store, which means the Apple Developer Program, App Review, and
  privacy-label disclosures — and keyboards that request Full Access + mic + background audio
  receive extra scrutiny.

What carries over from the macOS app: the transcription + cleanup pipeline is unchanged
(batch transcription via Groq / an OpenAI-compatible provider, then an LLM cleanup pass). The
keyboard reuses it as-is.

## 3. Decisions locked during brainstorming

Each was an explicit choice by the user:

1. **iOS only**, matching the Wispr Flow iPhone keyboard experience. (Android is a separate
   future effort; its IME has direct mic access and shares no code.)
2. **Build the keyboard first**, standalone. Backend and sync are separate later projects.
3. **Shared multiplatform Swift package** (not a copied/divergent iOS pipeline, and not a
   cross-platform framework). One source of truth so macOS and iOS transcribe and clean up
   identically — essential once they later share synced vocabulary and prompts.
4. **Full Flow Session from day one** (not a per-dictation app-bounce, not bounce-only): a
   held background-audio session with an auto-end timer, the `audio` entitlement, and the
   accepted extra App Review scrutiny.
5. **Batch per-utterance transcription** (not live-partial streaming): record a clip → Groq
   transcription → LLM cleanup → insert the final text. Reuses the existing pipeline as-is.
6. **Live Activity** for the session's visible presence (Dynamic Island + Lock Screen).
7. **Cloud is opt-in, later.** When the backend/sync projects happen, cloud + accounts are an
   opt-in tier layered on top, preserving the project's local-first, serverless promise (the
   README states "There is no Whispr Free Me server") and keeping the fork
   upstream-contributable. v1 of the keyboard is **local-only**.

## 4. Goals / non-goals

**Goals**
- A third-party iOS keyboard that dictates into any app: tap → speak → cleaned text inserted.
- The Wispr Flow feel: one bounce to start a session, then repeated dictation with no bounce.
- Identical transcription + cleanup behavior to the macOS app, via a shared package.
- Local-first and self-contained: the user supplies their own provider key; nothing leaves
  the device except calls to their configured transcription/LLM provider.

**Non-goals (v1)** — each is a separate later effort:
- Cloud sync, accounts, cloud voice storage, off-device voice-bank storage.
- "Speak as me" / TTS on iOS.
- Edit Mode and command mode.
- Context-aware cleanup from host-app content (not possible from an iOS keyboard regardless).
- Android.
- Rich vocabulary/snippet management UIs; live-partial / streaming transcription.

## 5. Architecture

The driving rule: **the containing app does all the real work; the keyboard stays thin.**

### Components

1. **Shared pipeline package** — multiplatform SPM target(s) for **macOS + iOS**: the
   transcription client (Groq / OpenAI-compatible), the LLM cleanup / post-processing, model
   configuration, and prompt templates. Consumed by both the existing macOS app and the new
   iOS targets. `Sources/Transcription` is already an SPM target; this work flips the package
   platforms to include iOS and pulls the post-processing + LLM transport
   (`LLMAPITransport`, `PostProcessingService`, `ModelConfiguration`) alongside it. The macOS
   app is refactored to depend on the package (low-risk; this logic is already fairly
   isolated).

2. **iOS containing app** — the workhorse:
   - Onboarding: enter the provider key (→ Keychain), enable the keyboard, grant Full Access,
     grant microphone permission.
   - **Flow Session engine**: owns the `AVAudioSession` and recording, runs the shared
     pipeline, manages the session lifecycle (start, auto-end timer, background keep-alive,
     teardown), and drives the Live Activity.
   - Listens for keyboard signals (Darwin notifications) and writes results to the App Group.
   - Settings screen (§6).

3. **iOS keyboard extension** — deliberately minimal, to survive the memory budget:
   - Renders the keys plus a prominent mic / Flow button with status (idle / recording /
     transcribing) and a recording indicator.
   - Starts/stops dictation and inserts the final text via `textDocumentProxy`.
   - On the first tap with no live session, launches the containing app to start the session
     (see §5.1 risk).
   - Requires Full Access. Contains no audio capture, no networking, no transcription.

4. **IPC bridge** — an **App Group** shared container (carries the transcript payload,
   session state, and a read-only config snapshot the keyboard reflects) plus **Darwin
   notifications** (`CFNotificationCenter`) for cross-process signaling (start / stop / done /
   heartbeat) between the two processes.

5. **Live Activity** (ActivityKit) — the session's visible surface on the Dynamic Island and
   Lock Screen: recording/idle state, session time remaining, a **Stop** control, and
   tap-to-open-app. Started by the app while it is briefly foreground during session start,
   then updated from the background as state changes. Interactive controls use App Intents
   (iOS 17+).

### Entitlements / Info.plist
- Keyboard extension: `RequestsOpenAccess = YES`.
- Containing app: `UIBackgroundModes: [audio]`, `NSMicrophoneUsageDescription`.
- App Group entitlement on both targets.
- Suggested identifiers (not final): app `…whisprfreeme.ios`, keyboard
  `…whisprfreeme.ios.keyboard`, App Group `group.…whisprfreeme`.

### 5.1 The one real technical risk — spike first

The fragile, under-documented part is **launching the containing app from the keyboard
extension** to start a session. The "return the user to their previous app" half is softened
by the Live Activity: rather than forcing a programmatic return, the session lives in the
Dynamic Island and the user navigates back themselves, with the island confirming it is live.
That reduces the risk to "launch the app once," which is the better-established half. Wispr
clearly achieves this and adapts when iOS shifts (their public "iOS 26.4" adaptation note).

**Mitigation:** a 1–2 day throwaway **spike is the very first task** — prove, on a current
iOS device, the launch + Live-Activity presence + Darwin-signaling round-trip (keyboard →
backgrounded app records/transcribes → text back → keyboard inserts). Fallback if the smooth
version cannot be achieved: the per-dictation app-bounce. Everything else (App Group,
background audio, the pipeline) is well-trodden.

## 6. Settings & data model (local now, sync-ready)

v1 is local-only. The app stores:
- **Provider config:** API key in Keychain; base URL + model ids — mirroring the macOS app's
  `KeychainStorage` / `ModelConfiguration`.
- **Cleanup config:** cleanup prompt / mode (default = the app's standard cleanup prompt);
  optional local custom vocabulary.
- **Session config:** auto-end timeout (default ~15 minutes; options through "never" — the
  primary battery lever), haptics/sound preferences.

A **read-only snapshot** of the settings lives in the App Group so the keyboard can reflect
state; the app owns all writes.

**Sync-ready shaping** (the only concession to the future, no sync built now): model the
syncable settings/vocabulary as **versioned `Codable` value types**, and keep keys aligned
with the macOS app's `UserDefaults` keys (`custom_vocabulary`, `custom_system_prompt`, …) so
the later sync project only has to add a transport that pushes/pulls these same structs.

## 7. Error handling & edge cases

- **No Full Access / mic permission denied** → the keyboard shows a clear prompt and a
  deep-link to Settings; dictation is inert until granted.
- **No network / transcription timeout / failure** → error state, insert nothing, allow
  retry; reuse the macOS app's configurable timeouts.
- **Empty or blocked transcript** (cleanup returns `EMPTY`) → insert nothing, gentle
  indicator.
- **App killed in the background** (OS memory pressure) → the keyboard uses a **heartbeat
  handshake** over the Darwin/App-Group channel; if the app is not alive, it falls back to
  relaunching to restart the session.
- **Session expiry mid-use** → the next tap re-bounces once to restart; the vanished Live
  Activity makes the ended state obvious.
- **Cursor moved / text field switched mid-transcription** → a short validity window so stale
  text is not inserted into the wrong field.
- **Secure (password) text fields** → iOS disables third-party keyboards automatically;
  expected, nothing to implement.
- **Extension memory pressure** → keep the extension UI light; never load audio or models in
  the extension.

## 8. Testing

- **Shared pipeline** — cross-platform unit tests building on the existing
  `Tests/TranscriptionTests`: request building, cleanup-prompt behavior, `EMPTY` handling.
- **IPC bridge** — App Group payload `Codable` round-trips; session-state machine
  (idle → recording → transcribing → idle) with the audio session behind a protocol so it is
  unit-testable; timer auto-end and teardown.
- **Manual device matrix** — keyboards cannot be meaningfully unit-tested for insertion, so a
  documented matrix on a real device: host apps {Messages, Mail, Safari, Notes, Slack, one
  third-party} × {start session, dictate, multi-dictation with no bounce, session expiry,
  no-network, no-Full-Access}.
- **Spike validation** — the §5.1 spike gets its own throwaway verification before any
  production code.

## 9. Build sequence (v1)

1. **Spike** (§5.1) — prove launch + Live Activity + Darwin round-trip on device. Gate.
2. **Shared package** — make the pipeline multiplatform; refactor the macOS app onto it;
   confirm macOS still builds and passes tests.
3. **Containing app skeleton** — onboarding, Keychain key entry, settings, App Group wiring.
4. **Flow Session engine** — `AVAudioSession` + background keep-alive, record → transcribe →
   cleanup, auto-end timer, Live Activity.
5. **Keyboard extension** — keys + Flow button + status; Darwin signaling; text insertion;
   Full Access prompts.
6. **Error handling + heartbeat**, then the manual device matrix.
7. **App Store prep** — privacy label, disclosures, review submission.

## 10. Risks & open questions

- **#1 — keyboard→app launch** (§5.1). Spike first; per-dictation bounce is the fallback.
- **Battery vs. the held session.** A held mic session is inherently not free; the levers are
  short default auto-end, aggressive teardown when the keyboard is dismissed / on Low Power
  Mode, and capturing efficiently (mono, modest sample rate — the pipeline already produces
  16 kHz mono). "Always on" and "very lightweight" are in tension; the resolution is short
  active windows and sane defaults, not a free always-on mic.
- **App Review.** Full Access + mic + background audio draw scrutiny; the Live Activity and a
  plain in-app disclosure of what is captured and where it goes help.
- **iOS version drift.** Apple periodically changes keyboard/extension behavior (cf. Wispr's
  "iOS 26.4" note); expect to adapt.
- **Provider streaming (future).** Live-partial transcription would need a streaming-ASR
  backend beyond batch Groq; explicitly deferred.

### Sources
- Apple Developer Forums — "Recording audio in keyboard extension": https://developer.apple.com/forums/thread/742601
- Apple — "Configuring open access for a custom keyboard": https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard
- "Limitations of custom iOS keyboards": https://medium.com/@inFullMobile/limitations-of-custom-ios-keyboards-3be88dfb694
- 9to5Mac — "Wispr Flow is an AI that transcribes what you say right from the iPhone keyboard": https://9to5mac.com/2025/06/30/wispr-flow-is-an-ai-that-transcribes-what-you-say-right-from-the-iphone-keyboard/
- Wispr Flow Help — "Set up the Flow keyboard on iPhone": https://docs.wisprflow.ai/articles/7453988911-set-up-the-flow-keyboard-on-iphone
- Wispr Flow Help — "Adapting to iOS 26.4": https://docs.wisprflow.ai/articles/6269634092-adapting-to-ios-26-4
