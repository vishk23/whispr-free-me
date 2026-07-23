# Voice Profile

Turn your banked dictations into a **voice pack** — a layered dataset any AI
agent can use to write in your authentic voice (website copy, bios, posts).
Your dictation history is your voice, captured at scale; this tool extracts
it and a guide turns it into a handoff artifact.

## What you get

A directory (default `~/VoiceProfile/`) containing:

| File | What it is | Who makes it |
|---|---|---|
| `corpus-full.md` | Every banked dictation, grouped by app context | `extract.py --source voicebank` |
| `corpus.md` | Recent dictations with heard-vs-cleaned diffs | `extract.py` |
| `VOICE.md` | The recipe: registers, rhythm, conviction, anti-patterns, curated exemplars | your AI agent, via `PROFILE_GUIDE.md` |
| `LEXICON.md` | Your vocabulary with exact counts, coinages, and the words you never use | your AI agent |
| `PATTERNS.md` | Long verbatim passages of how you reason out loud, organized by move | your AI agent |
| `README.md` | Tells a consuming agent how to use the pack | your AI agent |

Consuming agents read the small curated files first and search the corpus
for ground truth. Distillation on top, full data underneath.

## Extract the corpus

```bash
# Full uncapped archive (requires Voice Bank enabled in Rhapsode):
python3 Tools/voice-profile/extract.py --source voicebank --out ~/VoiceProfile/corpus-full.md

# Recent window with heard-vs-cleaned diffs:
python3 Tools/voice-profile/extract.py
```

The Pipeline History store is trimmed to a recent window; the Voice Bank
(`VoiceBank.sqlite`) is the uncapped archive and the right source for a full
corpus. Databases are copied before reading — a running app is never touched.

## Keep private material out: filters

Anything you've ever dictated is in the corpus — including things you may
not want in a file you hand to agents. Create `~/VoiceProfile/filters.txt`
with one case-insensitive regex per line (`#` for comments); any dictation
matching any pattern is dropped from every generated corpus, permanently —
the filter re-applies on each regeneration, so future automated rebuilds
stay clean too.

```
# example filters.txt
\bsome private phrase\b
name-of-a-person
```

`--filters PATH` overrides the location. The extraction summary reports how
many entries were filtered so you can sanity-check coverage.

## Build the profile

Give your AI agent (Claude Code, Codex, etc.) the extracted corpus and
[PROFILE_GUIDE.md](PROFILE_GUIDE.md) — it contains the full method:
frequency analysis first (counts, not vibes), then a complete read of the
corpus (fan out subagents for large corpora), then the layered write-up,
with verification and privacy rules. The guide exists so the result is
reproducible: regenerating next month with fresh dictations follows the
same recipe.

## Privacy

Everything generated here is your personal speech. Outputs are gitignored in
this directory and default to `~/VoiceProfile/` outside the repo. Never
commit a corpus, a profile, or your filters file.

## The `/write-as-me` skill

```bash
make install-skill
```

Installs the skill into **Claude Code** (`~/.claude/skills/`) and **Codex**
(`~/.codex/skills/`) — whichever you have; both agents use the same SKILL.md
format. After that, any session can draft copy in your voice:
auto-refreshing the corpus when it's stale, grounding drafts in your
verbatim words, and auditing against your lexicon. Re-run the installer
after moving the repo; it backs up any locally-modified install first.
Template: [skill-template/SKILL.md](skill-template/SKILL.md).

## Roadmap

An MCP server for clients without filesystem access (claude.ai, ChatGPT
desktop, mobile) exposing `get_voice_profile` / `search_corpus` over the
same extraction. Local agents don't need it — the skill plus the files
already cover them.
