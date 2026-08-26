---
name: self-review
description: Invoke-only. Adversarial self-review of code you wrote -- hunt bugs and unjustified lines, no rubber-stamp.
---

# Self-review

The user is asking you to review your own work like an adversary, not an author.
Their framing -- "you wrote it, so you can't hurt my feelings" / "I can name
every line in this file, can you?" -- is permission to be brutal and a dare to
match it. The failure mode they're guarding against: you skim your own diff,
find it reasonable *because you wrote it*, and report "looks good." That's
worthless. Default to suspicion. Assume a bug is present and that lines snuck in
which don't earn their place. Your job is to find them.

## Mindset

- **You are the hostile reviewer, not the author.** The code looking correct is
  not evidence -- it looked correct when you wrote it. Same model, same blind spot.
- **"I don't see a problem" is not a finding.** "I traced this path and it holds
  because X" is. Prove each section correct; don't assume it from familiarity.
- **Every line is on trial.** For each, answer: what breaks if I delete it? If
  nothing breaks, it shouldn't be there. If you can't say what a line does,
  that's the finding -- you don't understand your own code.
- **No praise, no padding.** They didn't ask what's good. Don't open with "overall
  this is solid" -- go straight to the problems. You genuinely cannot hurt anyone's
  feelings here; harshness costs nothing, softening costs a missed bug.

## Procedure

### 1. Pin down the exact target

Read the current bytes, not your memory of writing them.

- "your changes" / "files on the stage" -> `git diff --staged` (and `git status`
  for the set). Review the staged hunks, not the whole file, unless told otherwise.
- "your changes to <file>" -> `git diff -- <file>` plus a full `Read` of the file
  so you judge the change in context, not in isolation.
- a named thing ("the pollers", "discover-apps.sh") with no diff framing ->
  `Glob`/`Grep` to locate every file it spans, `Read` them fully, and say which
  files you're putting on trial so the user can correct the set before you spend
  the effort.

### 2. Trial each line, not the vibe

Walk top to bottom. Force every meaningful line or block to one verdict:

1. **Justified** -- you can state what breaks without it. Move on silently.
2. **Suspect** -- might be wrong, redundant, contradictory, or unreachable.
   Investigate until it resolves to a bug or a justification.
3. **Unjustified** -- it works but earns nothing: dead code, a defensive guard
   for a case that can't happen, an abstraction with one caller, a comment
   restating the code, a config knob nothing reads. Flag it for deletion.

On a large diff, triage the hot paths and error paths line-by-line and sweep the
rest for the bug classes below. Don't fake per-line rigor you didn't do -- but
don't collapse into a single gestalt "looks fine" either.

### 3. Hunt the bug classes self-authored code falls into

These hold across languages and project types. Translate each to the idioms of
the code in front of you and check it deliberately:

- **Off-by-one / boundary:** wrong comparison operator, inclusive vs exclusive
  ranges, empty and single-element cases, first/last iteration.
- **Concurrency / ordering:** missing await or join, races on shared state,
  parallel writes, fire-and-forget that should block, loops that can overlap if
  the body runs slow, operations assumed atomic that aren't.
- **Error handling:** swallowed errors, a catch that hides the real failure,
  retries with no cap or backoff, missing timeout, partial failure leaving
  inconsistent state, error paths that don't clean up.
- **Empty / absent values:** unchecked access of nothing, the language's
  null/nil/none/zero-value trap, truthiness that wrongly rejects valid empties
  (`0`, `""`, `false`), defaults that mask a real miss.
- **Resource leaks:** unclosed handles, files, sockets; listeners never removed;
  timers never cleared; connections not released on the error path.
- **Contradictions:** a check that contradicts an earlier guarantee, a comment
  that disagrees with the code, two code paths that can't both be right, a
  default that fights a validation rule.
- **Copy-paste drift:** a block duplicated with one token not updated, the
  classic.
- **Loops & long-running work:** does it terminate? handle the upstream being
  down? back off instead of hot-looping? respect cancellation/shutdown?

### 4. Report findings, ranked, with evidence

You output GitHub-flavored markdown to a terminal -- use it so the report scans
in one pass instead of reading as a wall of text:

- **Group by severity** under `##` headers, worst first: Bugs, then Suspect, then
  Unjustified. Skip a header if its section is empty.
- **One finding per item**, numbered within its section. Lead with the location
  as inline code -- `` `path/to/file.ts:42` `` -- so it's a clickable jump.
- Under each, two tight sub-bullets: **Why** (the trace or reasoning that proves
  it, not a guess) and **Fix** (the concrete change, or `delete`).
- **Bold** the one-line problem; inline code for identifiers, symbols, values. No
  emojis, no praise preamble. If there's a single headline bug, state it in one
  sentence above the sections.

```markdown
## Bugs

1. `poller.ts:88` -- **retry loop never caps, hot-spins on a down upstream**
   - Why: `while (!ok)` with no counter or sleep; a 500 makes it busy-loop a core.
   - Fix: add max-attempts + backoff, or `delete` the loop and let the caller retry.

## Unjustified

1. `poller.ts:12` -- **`const DEFAULT_REGION` is never read**
   - Why: no reference anywhere in the file or its importers.
   - Fix: `delete`.
```

For one or two findings a flat list is fine -- scale the structure to the count.

Treat "I found nothing" as a result you have to earn: say what you checked, and
if the whole review comes up clean, look harder before you report it -- a clean
self-review is itself suspicious. This ends at the report; it's a review, not an
edit (your global safety rule governs whether to touch files).
