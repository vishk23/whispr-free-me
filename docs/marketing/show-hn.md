# Show HN draft

Post from your own HN account (submissions can't be delegated). Best window:
Tue–Thu, 6–9am Pacific. Stay in the comments for the first 2–3 hours — HN
rewards engaged authors and buries drive-by promos. Expect (and welcome)
"why not just use X" comments; the honest comparison answers land well.

---

**Title** (80 char limit):

> Show HN: Rhapsode – Mac dictation with on-device fallback and your voice back

**URL**: https://github.com/vishk23/rhapsode

**Text**:

I dictate everything — messages, code comments, prompts — and got tired of
choosing between fast-but-cloud-only (Wispr Flow, $15/mo, bricks offline) and
local-but-slower open source. So I built the setup I wanted on top of the
excellent FreeFlow (zachlatta/freeflow), and it grew into its own thing.

The parts I think are technically interesting:

- Hedged transcription: Groq's hosted Whisper answers in ~0.7s normally; if
  it's silent for 4s (or errors at all), local whisper.cpp races it and the
  winner pastes. Offline, the whole pipeline runs on-device, including cleanup
  via Apple's foundation model — the full 6KB cloud prompt overwhelms the 3B
  on-device model into under-editing, so it gets a compact prompt plus a
  deterministic filler-stripper in front.

- Whisper's trailing "Thank you." hallucination is filtered with audio
  evidence, not heuristics: if the recorded audio has no voice energy inside
  that segment's timestamps, it never happened. A deliberately spoken
  "thank you" survives because the energy is there.

- The dictionary learns from your edits: after pasting, it re-reads the field
  via Accessibility, word-diffs what you changed, and phonetically-close
  respellings (Kava → Cava) become vocabulary — which feeds Whisper's prompt,
  a deterministic corrector, and the cleanup LLM next time.

- The opt-in Voice Bank stores your dictations locally; clone the voice via
  ElevenLabs and ⌥⌘S reads any selected text back as you, system-wide.

Free, MIT, bring your own Groq key (pennies/month at dictation volumes; the
default model tier is effectively free). Signed + notarized DMG, or build
from source with make.

Happy to answer anything about the pipeline — the hallucination filtering and
the on-device model prompting were the fun rabbit holes.
