# PROFILE_GUIDE.md — how an AI agent builds the voice pack

You are an AI agent with a dictation corpus (`corpus-full.md`) extracted by
`extract.py`. Your job is to produce the four curated files of a voice pack:
`README.md`, `VOICE.md`, `LEXICON.md`, `PATTERNS.md`. Follow this method —
it exists so regeneration is reproducible, not impressionistic.

## Principles

1. **Counts, not vibes.** Every vocabulary claim in LEXICON.md must be a
   real count over the corpus. Run frequency analysis before writing prose.
2. **Read everything.** Voice lives in the long tail — coinages used 3 times,
   one-off analogies, register shifts. If the corpus exceeds what you can
   hold, fan out subagents over line-range slices; never sample.
3. **Verbatim or nothing.** Exemplars and reasoning passages are exact
   quotes with timestamps. Never paraphrase and present as quotation. After
   drafting, spot-check quotes with grep against the corpus — a claim the
   user doesn't remember ("did I say that?") must be verifiable in seconds.
4. **Distill *on top of* the data, not instead of it.** The curated files
   point into the corpus; they don't replace it.
5. **Privacy is layered.** The extractor's `filters.txt` already removed
   what must never appear anywhere. Beyond that: sensitive-but-authorized
   material (e.g. personal journaling) informs register descriptions and
   cadence, and appears as exemplars only if the user has said so; and the
   profile must instruct consuming agents that private material is for
   *voice*, never *content* on a public page.

## Step 1 — Frequency analysis

Compute over raw transcripts: total entries/words; % of entries containing
"?"; counts for candidate signature phrases (discover via top trigrams and
4-grams, then count precisely); top sentence openers. Keep the numbers —
they go in LEXICON.md verbatim.

## Step 2 — Full read (fan out if large)

Split the corpus into 3-5 line-range slices and give each reader the same
mining brief:

- **Unique vocabulary & coinages** — term, rough count, one verbatim example.
- **Elucidation passages** — 5-7 LONG verbatim passages (60+ words, with
  timestamps) where the speaker reasons through a problem out loud:
  hypothesis chains, analogies, constructed counterfactuals, model-building
  interrogation.
- **Recurring constructions** — repeated sentence patterns/rhetorical moves,
  2-3 verbatim examples each.
- **Register & tone notes** — openings, closings, escalation ladder, how
  praise and dismissal sound, emotional range.
- **Content themes** — what projects/topics are narrated (these become raw
  copy for project writeups).

## Step 3 — Write the pack

- **LEXICON.md** — headline rates; signature-phrase table with counts and
  functions; casual-register table; coinages & personal idiom (the layer a
  surface pass misses); technical vocabulary the speaker owns; top n-grams;
  sentence openers; and a **conspicuously-absent list** (words with zero
  occurrences that generic AI copy would reach for — the never-write list).
- **PATTERNS.md** — 15-20 named reasoning moves, each with a one-line
  annotation and long verbatim passages. End with guidance on shaping copy
  like the reasoning (observation → hypotheses → resolution), not like a
  feature list.
- **VOICE.md** — the recipe: a preamble addressed to the consuming agent;
  register spectrum (one portrait per app context, plus which register
  anchors the target copy); rhythm & syntax patterns; emphasis & conviction;
  anti-patterns; verbatim project narrations as source material; a closing
  quick-recipe paragraph.
- **README.md** — file-reading order for consuming agents, corpus stats,
  the privacy instruction, and the regeneration commands.

## Step 4 — Verify

- Grep-verify every coinage and quote you attributed.
- Confirm zero matches for the user's filter patterns in every file.
- Sanity-check counts against the corpus header stats.

## Delivery

Write everything to the pack directory (default `~/VoiceProfile/`). Nothing
from the pack is ever committed to a repository.
