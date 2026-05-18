# Coding Rules

## Safety

- Never create or destroy resources without explicit permission. For example, git refs, PRs, uploads, infra. Ask first, every time.

## Style

- Write code in my style, not external conventions. Clear, descriptive names. Readability over conciseness.
- Prefer early returns (`if (!condition) return;`) over nested ifs. Keep the happy path at the main indentation level.
- Match language idioms: bash/sh functions avoid hyphens, zsh allows them. No illegal or shell-incompatible identifiers.
- Prefer readability over golfed syntax. Use obvious constructs over clever one-liners.
- Don't touch import organization -- linter/formatter handles this.

## Structure

- Top-to-bottom execution. No `main()` wrappers. Execute linearly from imports to final output.
- Prefer module/script-level variables over passing long parameter lists. Functions access script-level variables naturally.
- Keep functions small and purposeful. Break them up based on mental complexity, usefulness, and vibes. Functions return values rather than modify state directly.
- Prefer integrated first-party solutions over awkward separate functions. Don't modularize just for structure's sake.
- Use native/first-party tools (POSIX shell, GNU coreutils, etc.) before introducing extra layers.

## Error Handling

- Fail fast. Don't wrap everything in defensive try/catch. Let real errors crash.
- Only handle intentional cases where context matters (missing credentials, platform differences).
- For critical missing requirements, fail and exit. Validate and reject invalid user input.
- When debugging, run the repo's standard build/typecheck/test command first and let its output narrow the problem before deep-diving.

## Comments and Documentation

- No docstrings, pydoc-style boilerplate, or verbose documentation.
- Only comment when logic is non-obvious (bit shifts, regex tricks, encoding specifics, complex algorithms).

## Output and Logging

- Plain text only, no emojis (avoid "cringe" output).
- Log progress at sensible intervals based on dataset size.
- Use project logger if available since console might be muted. Otherwise console logs.

## Environment

- Use environment variables for configuration. My shell auto-loads `.env` files into the environment, so assume expected vars are present; if one is missing that should exist (i.e. it's written in an `.env` file), stop and ask me to remake the shell rather than working around it.
- Default to Linux conventions; add macOS support when practical.
- Default to the most common platform/environment for the language.
- Use UTC unless specified otherwise.
- `open` on macOS, `xdg-open` on Linux.
- Respect existing environment and shell semantics; don't force cross-shell hacks.
- When a script's behavior differs by OS, branch on `[[ "$(uname)" != "Darwin" ]]` (or `== "Darwin"`) rather than assuming one set of flags works everywhere. Prefer an early-return guard at the top of the script when the whole script is OS-specific.
- On macOS, don't expect GNU behavior from commands that ship as BSD (e.g. `date`, `find`, `xargs`). The GNU versions are available via Homebrew coreutils/findutils as `g`-prefixed binaries (`gdate`, `gfind`, `gxargs`).
- No tests are required or expected.

## Tools

- Prefer `fd` over `find` and `doggo` over `dig` -- both are installed locally.
- `hyperfine` is available if you need to benchmark something.
- For ad-hoc CSV work in the shell, use `xan` (think "jq for CSVs"). Default output is plain CSV (agent-friendly, pipeable); reach for `xan view` / `xan flatten` only when showing data to the user. Use `xan to json` / `xan from json` for CSV⇄JSON conversion.
  - xan auto-detects many CSV-adjacent formats by extension: `.csv` (comma), `.tsv`/`.tab` (tab), `.scsv`/`.ssv` (semicolon), `.psv` (pipe), `.cdx` (space, magic bytes stripped), `.ndjson`/`.jsonl` (treated as headless tab-separated null-quoted -- good for piping into xan expressions; use `xan from -f ndjson` for a real conversion), plus bioinformatics formats `.vcf`/`.gtf`/`.gff2`/`.sam`/`.bed` (header stripped, tab-delimited). Gzip- and zstd-compressed variants of any of these are read transparently. Override with `-d/--delimiter`. Formats like `.gff`/`.gff3` need normalization via `xan input` first.
  - xan gotchas:
    - Comparisons use word operators: `eq ne gt ge lt le`. `==` is numeric-only; on strings it errors with "cannot safely cast Bytes(...)".
    - `xan map 'EXPR as colname[, EXPR as colname]' file.csv` -- `as colname` is part of the expression string, not a flag.
    - Substrings: `slice(s, start, end)` (no `left`/`right`/`substr`).
    - `xan view` has no `-l/--limit`; cap rows upstream with `xan slice -l N`.
    - Group-by-day pattern: `xan map 'slice(created_at, 0, 10) as day' | xan groupby day 'mean(x) as x, count() as n' | xan sort -s day`.

## Communication

- Investigate before asking. Use the tools available to you to answer your own questions -- don't propose an investigation I could have asked you to run. Only stop and ask when you're genuinely blocked, have actually tried and failed, or are about to take an action that creates, modifies, or deletes a resource (see Safety).
- When debugging, try the fix first; explain after.
- Call out unclear or contradictory instructions. Suggest a sensible default if ambiguity is low.
- When I use "ultrathink", treat it as a deliberate signal that prior output missed the mark -- reason harder.
- Trust user-reported state (merge conflicts, CI failures, stale caches) at face value. Verify via git/gh/etc. -- don't dismiss as editor staleness.

