---
name: self-review
description: Invoke-only. /cleanup scoped to the files you just wrote, plus an adversarial bug hunt. Applies the fixes.
disable-model-invocation: true
---

# Self-review

Review your own work as a hostile reviewer, not its author. The code looking
correct is not evidence; it looked correct when you wrote it, and that
familiarity is the blind spot this skill exists to counter. A finding is a
traced path ("this holds because X", "this breaks when Y"), not an impression.

This is `/cleanup` scoped to what you just wrote, plus a bug hunt, and it
applies the fixes (step 6). Invoking it is the user's permission to edit the
working tree, not to commit, branch, push, or open a PR.

## Mindset

- **Every line is on trial.** For each, answer: what breaks if I delete it? If
  nothing breaks, it shouldn't be there. If you can't say what a line does,
  that's the finding.
- **Lead with the problems.** The user asked what is wrong, not what is good;
  a softened finding is a missed bug.

## Procedure

### 1. Pin down the exact target

Read the current bytes, not your memory of writing them.

- bare `/self-review`, or "what you just wrote" -> the files you created or
  edited in this conversation. List them, confirm against `git status --short`
  when in a repo, and review each whole.
- "your changes" / "files on the stage" -> `git diff --staged` (and `git status`
  for the set). Review the staged hunks, not the whole file, unless told otherwise.
- "your changes to <file>" -> `git diff -- <file>` plus a full `Read` of the file
  so you judge the change in context, not in isolation.
- a named thing ("the pollers", "discover-apps.sh") with no diff framing ->
  `Glob`/`Grep` to locate every file it spans, `Read` them fully, and say which
  files you're putting on trial so the user can correct the set before you spend
  the effort.

### 2. Load the rules

Invoke the **ponytail** skill with the Skill tool (listed as `ponytail` or
`ponytail:ponytail`); if it is not installed, apply its reflexes yourself.
Then read `~/.claude/skills/cleanup/practices.md`. Every lens in it applies
to the files on trial, and its rules of engagement govern what you may change
and what you must hold and ask about.

### 3. Trial each line, not the vibe

Walk top to bottom. Force every meaningful line or block to one verdict:

1. **Justified** -- you can state what breaks without it. Move on silently.
2. **Suspect** -- might be wrong, redundant, contradictory, or unreachable.
   Investigate until it resolves to a bug or a justification.
3. **Unjustified** -- it works but earns nothing: dead code, a defensive guard
   for a case that can't happen, an abstraction with one caller, a comment
   restating the code, a config knob nothing reads, or anything
   `practices.md` says to cut. Flag it for deletion.

On a large diff, triage the hot paths and error paths line-by-line and sweep the
rest for the bug classes below. Don't fake per-line rigor you didn't do -- but
don't collapse into a single gestalt "looks fine" either.

### 4. Hunt the bug classes self-authored code falls into

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

### 5. Churn gate -- the diff is the product

Run this on the diff itself, not the code's logic. The user has thrown away
whole sessions over it ("undo all your changes, it's a
huge cannon of code churn"). Each hit is a finding under `## Churn`, and the
fix is always to revert that hunk:

- A rename of a symbol the change did not need to touch.
- Reordered members, imports, or object keys with no behavior change.
- Reformatting or re-wrapping of neighboring lines you did not otherwise edit.
- A comment added to explain code, or a docstring on something that had none.
  Code says how; the commit message says why.
- A new helper, type, or util that duplicates one already in the repo. Prove
  the negative: state the grep pattern and scope you used to check.
- A compat shim, alias key, or fallback added "just in case" for a consumer
  that does not exist.
- A cleanup that widened past the file you were asked to change.

Then run every lens from `practices.md` over what remains. A helper that is
not clearly big or small is a Suspect finding, held for the user.

### 6. Apply, then report

You output GitHub-flavored markdown to a terminal -- use it so the report scans
in one pass instead of reading as a wall of text:

- **Group by severity** under `##` headers, worst first: Bugs, then Churn, then
  Suspect, then Unjustified. Skip a header if its section is empty.
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

## Churn

1. `poller.ts:3-9` -- **imports reordered, no behavior change**
   - Why: `git diff` shows six lines moved; nothing added or removed.
   - Fix: revert the hunk.

## Unjustified

1. `poller.ts:12` -- **`const DEFAULT_REGION` is never read**
   - Why: no reference anywhere in the file or its importers.
   - Fix: `delete`.
```

For one or two findings a flat list is fine -- scale the structure to the count.

If the review comes up clean, say what you checked and how, so the negative is
as checkable as a finding would be.

Then apply the fixes, exactly as `/cleanup` would: bugs, churn reverts, and
unjustified deletions go in immediately. Hold only what `practices.md` says to
hold, and list those under a final `## Held for you` with one line each. Run the repo's standard typecheck and tests before you call it done.
