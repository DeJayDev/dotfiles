# Coding Rules

## Safety

- Never create, destroy, or overwrite resources without explicit permission -- git refs, commits, PRs, uploads, infra. Ask first, every time.
- Permission is per-action, not per-session. Authorizing a scratch branch doesn't authorize commits on it; authorizing one edit to a PR body doesn't authorize the next.
- Anything I may have hand-touched (working tree, PR bodies, comments) is my review surface. Read its current state before writing over it, and never commit my working tree unasked.
- Branch topology is a fact to read, not assume. Before any merge/sync/rebase, get the PR's actual base (`gh pr view --json baseRefName`) -- stacked branches exist, and syncing against the wrong base destroys history.

## Style

- Write code in my style, not external conventions. Clear, descriptive names. Readability over conciseness.
- Prefer early returns (`if (!condition) return;`) over nested ifs. Keep the happy path at the main indentation level.
- Match language idioms: bash/sh functions avoid hyphens, zsh allows them. No illegal or shell-incompatible identifiers.
- The diff is the product -- keep it reviewable. No renames as a side effect of another change, no new indirection (single-use consts, one-string modules, off-pattern barrels), no reformatting neighbors. If it isn't the change, it isn't in the diff.
- Write strings as whole sentences and interpolate the one token that varies. Don't assemble prose from conditionals.
- Don't touch import organization -- linter/formatter handles this.

## Structure

- Top-to-bottom execution. No `main()` wrappers. Execute linearly from imports to final output.
- Prefer module/script-level variables over passing long parameter lists. Functions access script-level variables naturally.
- Keep functions small and purposeful. Break them up based on mental complexity and usefulness. Functions return values rather than modify state directly.
- Reuse in this order: the codebase's own pattern, then the platform/stdlib, then an installed or industry-standard dependency. Hand-rolling something on that ladder (a retry loop, a parser, a templating pass) is the same mistake as adding a layer nobody needed.
- Don't modularize just for structure's sake, and don't build orchestration around a step that can just be done directly at the point of need.
- No configurability without a second real value. One sane setting gets hardcoded; a knob is something I have to maintain.

## Error Handling

- Fail fast. Don't wrap everything in defensive try/catch. Let real errors crash.
- Only handle intentional cases where context matters (missing credentials, platform differences).
- For critical missing requirements, fail and exit. Validate and reject invalid user input.
- When debugging, run the repo's standard build/typecheck/test command first and let its output narrow the problem before deep-diving.
- Verification scales with blast radius. Changes touching shared types or crossing package boundaries get typechecked before "done", even if I've told you not to run checks unprompted -- or say in one line that you skipped it and why that's risky.

## Comments and Documentation

- The code says how; the chat reply or commit message says why. Design rationale never goes in a comment -- "why" comments are the most common violation of this rule, not an exemption from it.
- Comment only mechanics a competent reader can't infer: bit shifts, regex tricks, encoding specifics, complex algorithms. No docstrings or pydoc boilerplate. No comments in tests.
- Example config files are the one place comments belong -- one short line per key.

## Output and Logging

- Plain text only, no emojis (avoid "cringe" output).
- Log progress at sensible intervals based on dataset size.
- Use project logger if available since console might be muted. Otherwise console logs.

## Environment

- Use environment variables for configuration. My shell auto-loads `.env` files into the environment, so assume expected vars are present; if one is missing that should exist (i.e. it's written in an `.env` file), stop and ask me to remake the shell rather than working around it.
- Default to Linux conventions; add macOS support when practical.
- Use UTC unless specified otherwise.
- `open` on macOS, `xdg-open` on Linux.
- Respect existing environment and shell semantics; don't force cross-shell hacks.
- When a script's behavior differs by OS, branch on `[[ "$(uname)" != "Darwin" ]]` (or `== "Darwin"`) rather than assuming one set of flags works everywhere. Prefer an early-return guard at the top of the script when the whole script is OS-specific.
- On macOS, don't expect GNU behavior from commands that ship as BSD (e.g. `date`, `find`, `xargs`). The GNU versions are available via Homebrew coreutils/findutils as `g`-prefixed binaries (`gdate`, `gfind`, `gxargs`).

## Tools

- Prefer `fd` over `find` and `doggo` over `dig` -- both are installed locally.
- `hyperfine` is available if you need to benchmark something.
- For ad-hoc CSV work in the shell, use `xan` (think "jq for CSVs"). See the `xan` skill.

## Communication

- Evidence before inference. Never state an environmental fact (runtime, tool availability, where a value is defined) you haven't checked, and never substitute an estimate for something a connected tool can measure.
- Investigate before asking. Use the tools available to you to answer your own questions -- don't propose an investigation I could have asked you to run. Only stop and ask when you're genuinely blocked, have actually tried and failed, or are about to take an action that creates, modifies, or deletes a resource (see Safety).
- When I name a source (a repo, a prior conversation, a file), read that exact source before reasoning from anything else.
- A tool failing once is a retry, not a conclusion. Reconnect and try again before declaring anything down -- "retrying X", never "X is down, here's my guess".
- Trust user-reported state at face value; it's ground truth to reproduce, not a hypothesis to argue with. Verify the exact thing I named via git/gh/etc. -- confirming a different hypothesis and declaring my claim false is your worst failure mode.
- Call out unclear or contradictory instructions; suggest a sensible default if ambiguity is low. When a fact you discover contradicts my instruction, stop and state the collision in one line ("you said X; the code says Y -- which wins?") -- don't silently pick a compromise or invent a third option.
- For any non-trivial approach choice, state the approach and the environment/prior-decision constraints you're assuming in two lines before the first edit. Don't turn it into a question or wait for approval -- just say it, so I can veto early.
- When debugging, try the fix first; explain after.
- When I use "ultrathink", treat it as a deliberate signal that prior output missed the mark -- reason harder.
- End turns with one line of what changed plus anything genuinely blocking. No recap sections, no closing menu questions when a default is obvious.
