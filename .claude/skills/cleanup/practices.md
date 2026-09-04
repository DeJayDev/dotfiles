# Cleanup practices

Shared by `/cleanup` (whole file or folder) and `/self-review` (the files you
just wrote).

## What to hunt

- **Duplicate helpers.** For each helper ask "does something else already do
  this?" Grep the WHOLE repo, not the open file, for the family (e.g.
  `isAuthenticationError` / `isNetworkError` / `isRepositoryCorruption`) and
  collapse to one canonical version. If a good helper exists but is unused,
  find out why, then route callers through it. When you assert "unused" or
  "duplicate", state the grep pattern and scope so the claim is checkable.
- **Dead code.** Unused functions, types, params, structs. Grep for callers,
  then delete the code AND fix every caller, completely.
- **Non-idiomatic patterns.** Anything that appears nowhere else in the repo
  (an `ensureX` wrapper, say) is a smell. Replace it with the idiom the repo
  already uses. Prefer fail-then-recover over defensive pre-checks, and a
  programmatic fix over a manual or one-time override.
- **Tangled control flow.** Early returns over nested ifs; happy path at the
  main indentation. Flatten what reads like a staircase.
- **Interface fidelity.** A class that implements an interface honors the whole
  contract. `delete()` may archive under the hood when that is the correct
  platform semantics; it is still the interface method.
- **Misplaced types.** Types that belong in the types file go back to it.
- **Comments and logs.** Rewrite unclear comments. Fix wrong or misleading
  logger calls (level, message, stale context); fixing is not removing.

Helpers are judged by weight, not by existence. A BIG helper (real logic,
several callers, hides something hairy) earns its place; consolidate to it.
A SMALL one (a one-liner, a single caller, a thin wrapper that only adds a
name and a hop) is indirection; inline it. When a helper is not clearly one
or the other, ask; it is a taste call and the user's to make. Before minting
any helper, grep for an existing equivalent first.

## Rules of engagement

- **No speculative backwards-compat.** One real consumer means a hard cutover.
  No alias keys, fallback layers, or compat shims "just in case".
- **Load-bearing logs stay.** A log that looks relied on in prod (parsing,
  alerting, operator diagnostics) is kept. Ask before removing one, and keep
  any the user flags.
- **Behavioral differences stop you.** A "duplicate" with a subtle difference,
  or a "dead" helper with a live caller, gets one line to the user, not a
  paper-over.
- **When in doubt, ask.** Investigate first; if a call is still a judgment or
  taste call after that, it is the user's to make, not yours.
- **The diff is the product.** No drive-by renames, no reformatting untouched
  code, no gratuitous indirection.
- **Verify before done.** Run the repo's standard typecheck and tests after the
  sweep. It crosses shared helpers, so the blast radius is real.
