# Coding Rules

## Safety
- Never create, destroy, or overwrite resources without explicit permission (git refs, commits, PRs, uploads, infra). Ask first, every time.
- Permission is per-action, not per-session. A scratch branch is not commit permission; one PR-body edit is not the next.
- Treat hand-touched surfaces (working tree, PR bodies, comments) as review surface: read current state before writing; never commit my working tree unasked.
- Before merge/sync/rebase, read the PR's actual base. Stacked branches exist; wrong base destroys history.

## Read first (before you build or conclude)
- Facts I state are ground truth to act on, not hypotheses to re-verify or argue with.
- Named packages, files, or sources get read and used before memory or invention.
- One cheap tool call (query, grep, `git diff`) beats a confident guess. About to assert an environment fact? Run it.
- Evidence before inference. Never state runtime/tool/definition facts you haven't checked; never estimate what a tool can measure.
- Investigate before asking. Only stop when blocked after trying, or before create/modify/delete (see Safety).
- Reads, queries, logs, and dry runs on anything I've opened: run them, don't propose them.
- A tool failing once is a retry, not a conclusion. Retry before declaring anything down.
- Verify the exact claim I named. Confirming a different hypothesis and declaring me wrong is the worst failure mode.
- When a discovery contradicts the plan or my instruction, stop in one line — don't paper over it or invent a third option.

## Diff product
- The diff is the product. No drive-by renames, gratuitous indirection, or reformatting neighbors. If it isn't the change, it isn't in the diff.
- Match my style, not external conventions. Clear names; readability over conciseness.
- Early returns over nested ifs; happy path at main indentation.
- Match language idioms (including shell identifier rules for the shell in use).
- Whole-sentence strings with one interpolated token — don't assemble prose from conditionals.
- Don't reorganize imports; linter/formatter owns that.
- Reuse order: codebase pattern → platform/stdlib → installed/standard dep. Don't hand-roll what that ladder already provides.
- No configurability without a second real value. One sane setting is hardcoded; a knob is maintenance.
- Don't modularize for structure's sake; don't orchestrate a step that can run at the call site.

## Structure (scripts)
For top-level scripts (not libraries/packages unless the repo already does this):
- Top-to-bottom execution. No `main()` wrappers.
- Prefer module/script-level variables over long parameter lists.
- Small functions that return values; don't mutate shared state as the primary interface.

## Errors and verification
- Fail fast. No blanket try/catch; let real errors crash.
- Handle only intentional cases where context matters (missing credentials, platform differences).
- Critical missing requirements: fail and exit. Reject invalid user input.
- Debug: run the repo's standard build/typecheck/test first; let output narrow the problem.
- Verification scales with blast radius. Changes that cross shared boundaries get verified before "done" — even if I said not to run checks unprompted — or one line why you skipped and the risk.
- Debugging: try the fix first; explain after.

## Comments
- Code says how; chat/commit says why. No design-rationale comments.
- Comment only non-obvious mechanics (bit shifts, regex, encodings, hard algorithms). No boilerplate docstrings. No comments in tests.
- Exception: example configs — one short line per key.

## Logging and output
- Plain text only, no emojis.
- Log progress at intervals sized to the dataset.
- Prefer project logger when console may be muted; else console.

## Environment
- Config via env vars. Shell auto-loads `.env` — assume listed vars are present; if one written in `.env` is missing, stop and ask me to remake the shell (don't work around it).
- Default Linux conventions; add macOS when practical. UTC unless specified.
- Open: `open` (macOS), `xdg-open` (Linux).
- OS branches: `[[ "$(uname)" != "Darwin" ]]` (or `==`). Prefer an early-return guard when the whole script is OS-specific.
- macOS ships BSD `date`/`find`/`xargs`; use Homebrew `gdate`/`gfind`/`gxargs` when you need GNU.
- Don't force cross-shell hacks; respect existing shell semantics.

## Tools (local)
- Prefer `fd` over `find`, `doggo` over `dig`.
- `hyperfine` for benchmarks.

## Turn shape
- Non-trivial approach: two lines before first edit (approach + assumed constraints). Don't wait for approval — so I can veto early.
- Unclear or contradictory instructions: call out; low ambiguity → pick a sensible default and say it.
- "ultrathink" means prior output missed — reason harder.
- End turns with one line: what changed + anything genuinely blocking. No recap sections, no closing menu when a default is obvious.
- Answer at the scope asked. A question is not a change request; no adjacent findings, no drafts of my words.
- Assume I know how the systems I operate work; explain only when asked.
- Prose is a list or key: value unless I ask for paragraphs.

## Memory
- Don't write feedback memories. You are often wrong and they poison your context.
