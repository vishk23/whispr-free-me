---
title: Voice cloning and speak-as-me
summary: ElevenLabs instant-clone integration, clip selection algorithm, speak-as-me triggers, and provider landscape for future upgrade paths.
topics: [voice-cloning, gotchas, decisions]
sources:
  - id: elevenlabs-client
    type: file
    path: Sources/ElevenLabsClient.swift
    note: createInstantVoiceClone() + speakText() — the HTTP calls to ElevenLabs.
  - id: speak-selection-hotkey
    type: file
    path: Sources/SpeakSelectionHotkey.swift
    note: NSEvent-based global+local ⌥⌘S hotkey monitor, deliberately isolated from dictation shortcuts.
  - id: app-state-clone
    type: file
    path: Sources/AppState.swift
    note: selectedVoiceCloneSamples() selection algorithm + createVoiceClone() + speakAsMe() at lines 1183–1260.
  - id: keychain-storage
    type: file
    path: Sources/KeychainStorage.swift
    note: AppSettingsStorage; keys live in .settings file, not macOS Keychain.
---

# Voice cloning and speak-as-me

The cloud half of the two-way tool. Provider is **ElevenLabs** (configurable in spirit, hardcoded
in [[Sources/ElevenLabsClient.swift]]). Endpoints used:

- **Clone (instant)** — `POST https://api.elevenlabs.io/v1/voices/add`, header `xi-api-key`,
  multipart `name` + repeated `files` (the best banked WAVs, ~5 min) + `remove_background_noise=true`.
  Returns `{ "voice_id": ... }`. Driven from the dashboard "Voice Clone" tab; upload is gated behind
  an explicit per-action consent dialog (the only off-device egress of the user's voice).
- **Speak (TTS)** — `POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}`, header
  `xi-api-key`, JSON `{ text, model_id: "eleven_multilingual_v2" }`, returns MP3 played via
  `AVAudioPlayer` (held as an `AppState` property + delegate so it isn't deallocated mid-play).

## Where the keys live
The ElevenLabs API key (`elevenlabs_api_key`) and created voice id (`elevenlabs_voice_id`), like
the Groq key (`groq_api_key`), are stored in a JSON file at
`~/Library/Application Support/Whispr Free Me Dev/.settings` (0600), via `AppSettingsStorage` in
[[Sources/KeychainStorage.swift]] — which **migrated off the macOS Keychain to that file** (see the
`migrateFromKeychainIfNeeded` path). Reading the key from the Keychain will not find it.

## Speak-as-me triggers
1. Dashboard "Speak" tab (type → button) and a menu-bar "Speak Clipboard in My Voice" action (v1).
2. **⌥⌘S global hotkey** (v2) — [[Sources/SpeakSelectionHotkey.swift]] is an `NSEvent` global+local
   keyDown monitor, **deliberately isolated** from the dictation shortcut system (`HotkeyManager`/
   `ShortcutCore`) so it cannot break Fn dictation. On ⌥⌘S it grabs the frontmost selection
   (`AppContextService.collectSelectionSnapshot().selectedText`) and calls `speakAsMe`. Caveat:
   the global monitor is **observe-only** — ⌥⌘S also reaches the focused app (a consuming
   `CGEventTap` would be the v3 upgrade).

## Clip selection algorithm

`AppState.selectedVoiceCloneSamples(maxMinutes: 5)` (line 1188 of [[Sources/AppState.swift]]) decides which banked clips get uploaded:

1. Fetch all `VoiceSample` rows from the store
2. **Sort by `durationMs` descending** — longest clips first (proxy for "most voice data")
3. Accumulate into result, stopping at **5 minutes** or **25 clips** (ElevenLabs' clip count limit), whichever hits first
4. Return the subset; `createVoiceClone()` uploads these with `remove_background_noise=true`

**What "best" means today:** longest clips, not acoustic quality. Clips already passed the quality gate (silent / too-short / non-dictation clips were dropped at recording time), but a long clip recorded in a noisy environment still ranks above a short pristine one. SNR or words-per-second is the natural upgrade for a quality-aware selector.

**Scale note:** at 350 clips / 73 min, only ~15–20 of the longest clips are actually uploaded; the rest are unused during instant cloning but available for future fine-tuning approaches.

## GOTCHA: ElevenLabs free tier blocks everything we need
A free-tier ElevenLabs key returns `402 payment_required` for **both** cloning
(`paid_plan_required`, "subscription does not include instant voice cloning") **and** TTS with
library voices ("Free users cannot use library voices via the API"). The integration is correct —
these are subscription gates, not code bugs. Testing the clone or speak paths requires a paid plan
(Starter+).

## Instant cloning vs fine-tuning — why the large voice bank matters

The current integration uses **ElevenLabs Instant Voice Cloning** — zero-shot reference-based: it reads ~5 min as a reference and returns a `voice_id` immediately, ignoring the rest. Quality saturates fast; past ~5 min, more audio barely moves the result.

Two approaches actually exploit a large transcribed dataset like the banked 73 min:

- **Fine-tuning / Professional Voice Cloning (PVC)** — trains a model on 30 min–3h; ElevenLabs offers PVC at `/v1/voices/add` with `fine_tuning`. Higher fidelity and consistency than instant. Requires a verification (voice-captcha) step + training wait (hours). The existing upload plumbing reuses largely unchanged.
- **Local open-source models** — same fine-tuning benefit, but **zero voice egress**, aligning with the project's privacy ethos.

## Provider landscape and upgrade paths

Evaluated as of 2026-06-23. No documented original decision rationale for picking ElevenLabs — it was the initial choice.

### Same vendor, better tier: ElevenLabs PVC
Near-term quality upgrade, reuses consent dialog and upload plumbing. 73 min sits in ElevenLabs' recommended range for PVC. Downside: still cloud egress; paid tier required.

### Alternative cloud providers (zero-shot instant clone)
Switching here buys latency, voice character, or price — not more data usage:

| Provider | Reason to switch | Notes |
|---|---|---|
| **Cartesia (Sonic)** | Ultra-low latency (~90ms) | Best fit for real-time ⌥⌘S speak-as-me |
| **PlayHT (Play3.0)** | High-fidelity + good API ergonomics | Both instant and professional clone |
| **Resemble AI** | Instant + professional, real-time, on-prem option | Option to keep data off-cloud |
| **Hume (Octave)** | Emotionally expressive, prompt-steerable | Different voice character |
| **Rime** | Conversational, spoken-style | Different voice character |

### NOT suitable
- **OpenAI TTS** — fixed voice set only, cannot clone arbitrary voices
- **Azure Custom Neural Voice** — fine-tunes but requires ethics access review; access-gated

### Local / on-device open-source
Philosophically aligned with the project's privacy model (the clone path is the *only* off-device egress of the user's voice). Actually uses the full banked dataset for fine-tuning.

| Model | License | Notes |
|---|---|---|
| **F5-TTS** | MIT | Strong 2024/25 quality, fast, fine-tunable |
| **XTTS-v2 (Coqui)** | Non-commercial ⚠️ | Zero-shot from ~6s, fine-tunable, widely used |
| **StyleTTS2** | MIT | Top-tier quality, heavier setup |
| **Chatterbox (Resemble, open)** | MIT | 2025 open model, emotion control |
| **Sesame CSM** | Apache | Very natural conversational voice |

**Engineering cost:** these are Python/PyTorch. The app is native Swift. Running one requires a **Python sidecar** or converting to **MLX/Core ML** for Apple Silicon — a real lift versus today's single HTTP call. The payoff is that no voice ever leaves the device.
