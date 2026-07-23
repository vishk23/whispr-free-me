---
name: write-as-me
description: Write copy in the user's authentic voice using their dictation-derived voice pack (~/VoiceProfile). Use when the user asks to draft or review copy, bios, posts, or website text "in my voice" / "as me" / "sound like me". Also handles refreshing the pack from new dictations.
---

# Write As Me

<!-- INSTALL: run `make install-skill` from the repo root (or
     Tools/voice-profile/install-skill.sh) — it installs this skill into
     Claude Code (~/.claude/skills/) and Codex (~/.codex/skills/), whichever
     exist, with the repo path filled in and this comment stripped. Both
     agents use the same SKILL.md format. Build your voice pack first:
     Tools/voice-profile/README.md. Manual alternative: copy it yourself and
     replace the placeholder repo path in the commands below. -->

The user's voice pack lives in `~/VoiceProfile/` — a layered profile
distilled from their Rhapsode dictation archive. This skill drafts text that
sounds like them, grounded in that pack.

## Step 1 — Freshness check

```bash
ls -l ~/VoiceProfile/corpus-full.md
```

If the corpus is **older than 7 days**, or the user asks for a refresh,
regenerate (exclusion patterns in `~/VoiceProfile/filters.txt` re-apply
automatically — never bypass them):

```bash
python3 RHAPSODE_REPO/Tools/voice-profile/extract.py --source voicebank --out ~/VoiceProfile/corpus-full.md
python3 RHAPSODE_REPO/Tools/voice-profile/extract.py
```

The corpus regenerates in seconds. The curated files (VOICE/LEXICON/PATTERNS)
only need rebuilding when the corpus has grown substantially or the user
asks — follow `RHAPSODE_REPO/Tools/voice-profile/PROFILE_GUIDE.md` exactly.
If the curated files don't exist yet, offer to build them now via that guide.

## Step 2 — Load the pack

Read, in order: `~/VoiceProfile/README.md`, `VOICE.md`, `LEXICON.md`,
`PATTERNS.md`. They are small; read them fully. Do NOT read corpus-full.md
end to end.

## Step 3 — Ground the draft in their actual words

Before writing about a specific topic or project, search the corpus for what
the user has actually said about it:

```bash
grep -i -B1 -A2 "<topic keywords>" ~/VoiceProfile/corpus-full.md
```

Prefer tightening their verbatim narration over inventing new phrasing. For
structure, shape explanatory copy like their reasoning moves in PATTERNS.md,
not like a feature list.

## Step 4 — Draft, then audit

Draft per VOICE.md's register guidance. Then audit the draft:

1. Every word on LEXICON.md's conspicuously-absent list removed.
2. No generic AI-copy tells the profile warns against.
3. First person always, unless the profile says otherwise.
4. Rhythm matches the profile's syntax patterns, not default LLM cadence.

## Boundaries

- Private/journaling material informs cadence only — never content on
  anything public. The corpus is pre-filtered by the user's exclusion
  patterns; do not go around the filter to raw databases.
- Show the user which verbatim corpus material the draft drew from.
- Pack files and corpora never get committed to any repository.
