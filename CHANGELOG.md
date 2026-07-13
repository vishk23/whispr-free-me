# Changelog

All notable changes to Rhapsode are documented here.

This project uses semantic versioning for public releases. Use `MAJOR.MINOR.PATCH`, where:

- `MAJOR` changes include breaking behavior or major compatibility changes.
- `MINOR` changes add user-visible features and improvements.
- `PATCH` changes fix bugs, polish existing behavior, or make small internal improvements.

## [0.5.2] - 2026-07-13

### Fixed

- **Your words always paste now.** The cleanup LLM could refuse a dictation on
  content grounds and its stock refusal ("I'm sorry, but I can't help with
  that.") pasted INSTEAD of your words. A refusal is never valid output from a
  formatting layer: a new detector catches refusal-shaped output on every
  cleanup path (cloud, retry, on-device, Edit Mode) and falls through the
  existing chain — fallback model, then on-device polish, then the raw
  transcript — so the speaker's words land regardless of topic. Genuinely
  dictated refusal-shaped sentences ("I'm sorry, but I can't help with that")
  still paste, because the raw transcript starts the same way.
- The cleanup prompt now states it is a transcription layer that never judges
  content, and formats spoken clock times ("the gap from 313 to 329" ->
  "the gap from 3:13 to 3:29").

## [0.5.1] - 2026-07-10

### Fixed

- Whisper could parrot the vocabulary prompt onto the quiet tail of real
  speech, pasting your dictionary terms at the end of a message. A trailing
  run of two or more vocabulary terms in prompt order (comma-joined — the
  echo's signature) is now stripped; genuine endings like "...coffee at
  Dunkin'" or spoken "Cava and Dunkin'" lists are untouched.
- The vocabulary corrector could rewrite real words that shared a coarse
  phonetic class with a dictionary term ("Java" -> "Cava"). Word-initial
  letters now require an exact match or the C/K/Q hard-sound group.

## [0.5.0] - 2026-07-10

### Changed

- **Renamed to Rhapsode** (from Whispr Free Me): app name, bundle ids
  (`com.vishk23.rhapsode`), log subsystems, repository, docs. Existing data
  (voice bank, history, whisper model, settings file) migrates automatically
  from the old Application Support directory on first launch; macOS treats the
  new bundle id as a new app, so permissions must be granted once.
- The in-app updater now watches this repository's releases instead of
  upstream FreeFlow's.

### Fixed

- A wedged microphone start (no audio ever arriving) now fails loudly after
  10s and recovers on the next dictation, instead of spinning forever.
- Dev-build detection was still comparing against the original "FreeFlow Dev"
  name; it is now name-agnostic.

## [0.4.0] - 2026-07-10

Released as "Whispr Free Me" (renamed Rhapsode in 0.5.0). First release
intended for use beyond the author's machine. Built on FreeFlow (upstream
merged through 2026-07-10) plus the following.

### Added

- **Voice Bank** (opt-in, local-only): each dictation's audio + transcript build
  a voice-training dataset. Browse, play back, delete in Settings; menu-bar
  indicator while banking. Nothing is uploaded.
- **Voice cloning + speak-as-me**: clone your banked voice via ElevenLabs and
  read any selected text aloud in your own voice with ⌥⌘S.
- **Dashboard**: Stats (streaks, WPM, activity chart, top apps), History
  (search, Heard-vs-Cleaned comparison, audio playback, re-transcribe, failure
  badges), Modes editor, Dictionary, Snippets, Clone, and Speak tabs.
- **Editable content-aware modes**: the Formal/Code/Casual/Standard routing is
  now user-editable — custom modes, per-mode prompt snippets and cleanup-model
  overrides, app bundle-id and browser-tab (window-title) matching.
- **Offline resilience**: automatic on-device whisper.cpp fallback when the
  provider is unreachable, erroring, or slower than 4s (hedged race); offline
  cleanup via Apple Intelligence with a deterministic filler/stutter pre-pass;
  "Transcribed on-device" pill notice; Settings → Offline Fallback with
  one-click model download.
- **Vocabulary intelligence**: custom dictionary feeds the Whisper prompt, a
  deterministic phonetic corrector (compact-window merges like "chat g p t" →
  "ChatGPT"; homophone fixes like "kava" → "Cava"), and the cleanup LLM — and
  the dictionary grows itself by learning respellings from your post-paste
  edits (locally, via Accessibility).
- **Hallucination defense**: trailing fillers ("Thank you.") stripped using
  per-segment audio-energy evidence; trailing-silence trimming before upload;
  dictionary-echo guard for silent clips.
- **Latency**: transcription connection prewarms at record start; keep-alive
  upload session (self-healing); cleanup skipped entirely for ≤3-word
  dictations.
- **Paste polish**: smart leading space via Accessibility (no more mid-text
  "wordword" jams).
- Live partial-transcript display in the recording pill when a realtime
  streaming provider is configured.

### Changed

- Rebranded from FreeFlow to Rhapsode (bundle ids, log subsystems,
  docs); `make release` builds a production-named signed DMG.
- Context screenshots migrated from legacy CGWindowList capture to
  ScreenCaptureKit, fixing stuck "Screen Recording Permission Needed" states
  on macOS 14+.
- The calibrated casual-mode register (keep commas/caps, drop only the final
  period) ships as the default Casual snippet.

### Fixed

- Session-level 30s resource timeout no longer caps long transcription
  uploads; menu-bar app opted out of automatic termination so recordings
  can't be killed under memory pressure.

## [1.1.0] - 2026-06-03

### Added

- Model pickers in Settings for post-processing, fallback, context, and transcription models, including Qwen 3 32B and custom model entries.
- A recording overlay display picker for choosing the active window, primary display, or a specific connected monitor.
- In-pill error notifications so transient failures such as network or provider errors are visible without opening logs.
- Advanced timeout overrides for local model and slow network setups.

### Improved

- Retried dictations now place the successful transcript on the clipboard and update Paste Again.
- Paste Again now preserves the latest raw transcript earlier in the dictation flow, so it remains useful if later cleanup or pasting fails.
- Post-processing handles reasoning-oriented model output more cleanly, including Qwen thinking tags and providerless model aliases.

### Fixed

- Fixed cases where transcription could hang indefinitely when a provider accepted a connection but never returned a response.
- Fixed false screen-recording permission alerts from unrelated permission messages.
- Fixed duplicate in-pill error notifications being dismissed by an older timer.

## [1.0.0] - 2026-05-20

FreeFlow is now considered feature-complete and stable enough for a 1.0 release.

### Added

- Paste Again shortcut for re-pasting the most recent dictation.
- Recent transcript history in the menu bar, with copy actions for quickly reusing previous dictations.
- Run Log copy controls for both literal and cleaned transcript output.
- Menu bar actions for opening the Run Log and checking for updates.
- Debug settings for troubleshooting overlays and update prompts.
- A polished drag-to-Applications DMG background for installer builds.

### Improved

- Recording feedback now uses a cleaner minimalist menu-bar overlay, with clearer command-mode state.
- Transcribing and processing feedback appears sooner and more consistently after recording stops.
- Shortcut labels now use friendlier modifier names alongside symbols.
- Setup and recovery flows are more resilient when restoring app state.
- Sentence-ending dictations now paste with trailing spacing that better matches normal writing.
- Development builds and main-branch release automation are easier to identify and validate.

### Fixed

- Fixed shortcut collision checks for edit mode and manual modifier bindings.
- Fixed cases where dictation could terminate automatically while still in progress.
- Fixed clipboard restoration after dictation when the original clipboard content is unchanged.
- Marked transient dictation clipboard contents so clipboard managers can avoid saving them.
- Preserved spoken instructions verbatim during post-processing.
- Simplified transcription submission errors into clearer one-line messages.

## [0.3.3] - 2026-04-25

### Added

- Output Language setting for automatically translating dictated text before it is pasted.
- Transcription Language setting for choosing the language FreeFlow listens for during dictation.
- Recording state flag file for external tools that need to know when FreeFlow is actively recording.
- Distinct FreeFlow Dev app and menu bar icons so development builds are easier to tell apart from release builds.

### Improved

- Permission prompts and setup screens now use the correct app name for the installed build.
- Release notes in update prompts now render changelog formatting more clearly.
- Development builds now have clearer bundle naming and icon handling.

### Fixed

- Fixed audio recording crashes caused by unexpected input formats, resampling, and upload-path conversion.
- Fixed cases where FreeFlow could silently fall back when the selected microphone was unavailable.
- Fixed paste shortcuts on Colemak-DH and other non-QWERTY keyboard layouts.
- Fixed output language handling when custom system prompts are enabled.

## [0.3.2] - 2026-04-23

### Fixed

- Removed the pause-based audio interruption mode that could misfire and resume playback unexpectedly; dictation now only mutes audio.

## [0.3.1] - 2026-04-23

### Added

- Faster live dictation with realtime transcription support.
- A setting for choosing the realtime transcription model.
- Run log exports, so you can save a full dictation run for debugging or sharing.
- A Copy Transcript action in the run log.
- A voice command for submitting text: say "press enter" at the end of a dictation.
- Audio controls that can mute or pause other audio while you dictate, then restore it when recording stops.
- Build details in Settings for easier troubleshooting.
- Direct shortcuts from FreeFlow to the right macOS permission settings.
- A What’s New popup when an update is available.

### Improved

- Recording feedback now feels more responsive.
- The run log is easier to scan and use.
- Exported run logs include more useful context for reproducing issues.
- Realtime transcription is more reliable when recordings are cancelled, retried, or finish with no text.
- Provider settings are easier to edit without accidental whitespace or half-saved values.
- FreeFlow now warns you if alert sounds may be hard to hear because system audio is muted or very low.
- Update prompts now show the version, release date, and release notes more clearly.
- FreeFlow now uses proper version numbers for updates instead of internal build names.

### Fixed

- Fixed cases where arrow or navigation keys could be mistaken for Fn shortcut input.
- Fixed a clipboard timing issue that could paste the wrong content.
- Fixed empty realtime transcriptions getting stuck instead of finishing cleanly.
- Fixed waveform glitches caused by invalid audio levels.
- Filtered out more common transcription artifacts.
- Fixed alert sound hints staying visible after alert sounds are turned off.
- Fixed update checks so users only see real app releases, not internal builds.
- Fixed update checks so the app does not offer an older or already-installed version.
