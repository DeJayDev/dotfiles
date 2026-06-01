---
name: perforce-learnings-test
description: >
  Invoke-only. Run the end-to-end test for Perforce review learnings against the
  greptile-dev Swarm instance from the `perforce_on_worker` branch in greptilia.
  Covers env setup (P4 ticket, .env files), service launch, triggering a terminal
  state transition on a Swarm review, and verifying the worker's learn step fires.
  Use only when the user explicitly invokes the skill or asks to "test Perforce
  learnings end-to-end" -- do not auto-fire on general Perforce work.
---

# perforce-learnings-test

End-to-end test for the Perforce review-learnings pipeline. Owns the recipe captured during the initial wiring-up of the feature; the gotchas here are not obvious from reading the code.

## Hard rule: never run `gdev`

`gdev` is Dj's interactive dev-stack launcher. It needs a real TTY and does not survive the Bash tool. Every prior attempt has hung the session. **Do not run it, do not background it, do not pipe it, do not wrap it in `script`/`expect`/`nohup`/tmux from inside Claude.** If the stack isn't running, ask Dj to boot it in his own terminal and hand you the log path. You only read the log.

## What "working" means

The pipeline succeeds when, in response to a Swarm review transitioning to a terminal state, you see (in order, in the gdev log):

1. `apps/webhook` logs: `Pushed Swarm state transition to worker { reviewId, terminalStatus, correlationId }`
2. `apps/worker` logs: `filtering event` (filter step ingests the event)
3. `apps/worker` logs either:
   - `learn task completed` with `memoriesLearned: <n>` (success), OR
   - `No review comments to learn from` (review had no inline Greptile review comments — wiring works but no learning produced)

Anything else is a regression.

## Pre-flight

You authenticate to Swarm **as Dj (`$P4USER`, typically `abhinav`)**, using
his all-hosts ticket from `~/.p4tickets`. Do not authenticate as `rav` or any
bot account, and do not source `apps/*/.env` to pick up a different identity
-- the test is "Dj kicking the pipeline," not "the bot acting on its own
review."

`~/.p4tickets` is the canonical store the p4 CLI maintains (last `p4 login
-ap` writes it). It can diverge from whatever literal value lives in
`~/greptile/.p4config.local` -- the shell-exported `$P4PASSWD` may be a
stale or host-locked variant. Always read from `~/.p4tickets`.

```bash
# Extract Dj's all-hosts ticket without printing it.
TICKET=$(grep -F "=${P4USER}:" ~/.p4tickets | tail -1 | awk -F: '{print $NF}')

curl -s -o /dev/null -w '%{http_code}\n' -u "${P4USER}:${TICKET}" "$SWARM_URL/api/v11/projects"
# Expect: 200
```

If the extraction yields an empty `TICKET`, the file doesn't contain a
ticket for `$P4USER` (Dj never ran `p4 login` since the file was wiped, or
the file path differs on his machine). Stop and ask Dj to run `p4 login
-ap` in his interactive shell.

If Swarm returns **401** with a non-empty ticket, the ticket is host-locked
(generated without `-a`) or expired. Ask Dj:

```bash
# Dj runs this in his interactive shell -- p4 login is interactive, Claude
# cannot run it (non-tty stdin + auto-mode classifier blocks ticket extraction).
p4 login -a              # writes an all-hosts ticket into ~/.p4tickets
```

No file edit, no Claude restart needed -- once `~/.p4tickets` is updated, the
next `TICKET=$(grep ...)` in this Claude session picks up the new value.

If Swarm returns **500**, that's its quirky error code for bad credentials --
same recovery path.

## Critical gotchas (the parts that cost real time)

### 1. Service env files: per-app, not root

`turbo dev` runs each app from its own workspace cwd. Each app's `dotenv.config()` loads from its own dir (`apps/<app>/.env.local` then `apps/<app>/.env`), **not** the repo root. The root `.env` is in `globalDependencies` only for cache-busting.

`apps/<app>/.env.local` is auto-generated from `config/config.development.yaml` and gets wiped on regen. Use `apps/<app>/.env` (manual override, dotenv loads it second so app-local wins for shared keys but `.env` fills gaps).

The shell-exported `P4USER` / `P4PASSWD` from `.p4config.local` propagates to
subprocesses as long as neither the auto-generated `.env.local` nor a manual
`.env` for the app sets those keys. If a subprocess complains about Swarm
auth (`Integration missing P4 credentials`, 500 on review fetch), check
whether `apps/<app>/.env*` is shadowing the shell value.

### 2. State-poller dedup is per `(reviewId, newStatus)` in Redis

If you transition a review to `archived` once and it fires, the dedup key `swarm:state:emitted:<swarmUrlHash>:<reviewId>:archived` is set with a ~30-day TTL. Re-archiving the same review is a no-op.

To re-test on the same review, transition to a **different** terminal status (`needsReview` → `rejected` is a fresh combo). Or pick a different review.

The dedup state lives in the dev Redis (shared ElastiCache Serverless `greptile-cache-aasygv.serverless.use1.cache.amazonaws.com`); restarting gdev does not clear it.

### 3. Swarm `transitions` endpoint expects `transition`, not `state`

```bash
curl -u "$P4USER:$TICKET" -X POST -H 'Content-Type: application/json' \
  -d '{"transition":"archived"}' \
  "$SWARM_URL/api/v11/reviews/<id>/transitions"
```

Valid transition values from `needsReview`: `approved`, `needsRevision`, `rejected`, `archived`. From `archived` the valid set is `needsReview` only. `approved:commit` is a derived state — Swarm sets it automatically when an approved review has commits in `commits[]`; you cannot transition to it directly. In dev, auto-promotion may not fire, so for testing prefer `archived` or `rejected` (both map to `closed` in the parser).

### 4. Filter step skips post-commit reviews

`apps/worker/src/steps/filter.ts:758-763` short-circuits any Perforce review where `pr.metadata.isPostCommit` is true (i.e. the review's CL has been submitted via `p4 submit`). The state-poller will fire and the filter will start, but learn step never runs.

If you submitted a CL backing a review, that review is permanently off-limits for the learnings test. Pick a fresh review whose CLs are still shelved/pending.

### 5. "Greptile Filter — Automatic reviews are disabled" = `skipReview: AUTOMATIC` in the merged config

The banner is emitted by `apps/worker/src/steps/filter.ts:531` (constant `FILTER_MESSAGES['SKIP_REVIEW_AUTOMATIC']`) when `checkConfig` returns `'SKIP_REVIEW_AUTOMATIC'` at `filter.ts:1352`. That happens iff the *effective* merged config has `skipReview: 'AUTOMATIC'` for the files in the review.

The merge rule (`packages/settings/src/merge.ts:574-581`):

- Any applicable config setting `skipReview: 'NEVER'` → effective is `NEVER`, no skip.
- Else, only if **every** applicable config sets `'AUTOMATIC'` → effective is `'AUTOMATIC'`, banner posted.
- Otherwise unset → no skip.

"Applicable configs" are the cascading `.greptile` / `greptile.json` files resolved per-changed-file plus the integration/repo-level config. So this is neither a global integration kill switch nor a per-path coverage thing — it's a config field. Manual/dashboard triggers (`isOverride`) bypass the check entirely.

For the learnings test you want Greptile to auto-review. Either pick a review whose changed files' config cascade does **not** unanimously have `AUTOMATIC` (an existing review with Greptile inline comments already on it is proof), or drop a `.greptile` file with `{"skipReview": "NEVER"}` covering the path of your test files before shelving the CL.

## Recipe

### 1. Boot the stack

**STOP. Do NOT run `gdev` yourself.** `gdev` is an interactive launcher Dj runs in his own terminal; it does not work in a non-interactive shell (no TTY, no pty, no muxer attach). Every time an LLM has tried, it has wedged. If you run it, Dj has said he will turn the machine off mid-session. Don't.

Instead:

1. Ask Dj to run `gdev` in his interactive shell if it isn't already up.
2. Ask Dj for the named log path it printed (something like `~/.greptile/gdev/<run>.log`).
3. You only ever `tail` / `grep` that file. Never spawn the stack.

Expect within ~30s of Dj's boot, in that log:

```
webhook: "Swarm comment polling scheduled"
webhook: "Swarm state polling scheduled"
webhook: "Cold start: seeded lastProcessedId"
webhook: "Cold start: seeded state cursor"
```

If the log shows `Integration missing P4 credentials`, env didn't reach the webhook subprocess — see gotcha 1. Ask Dj to fix and restart gdev; don't restart it yourself.

### 2. Pick a victim review

```bash
# Re-extract TICKET if you're starting from a fresh shell.
TICKET=$(grep -F "=${P4USER}:" ~/.p4tickets | tail -1 | awk -F: '{print $NF}')

# List recent reviews + state
curl -s -u "$P4USER:$TICKET" "$SWARM_URL/api/v11/reviews?max=20&fields=id,state,author" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); [print(r["id"], r["state"]) for r in d["data"]["reviews"]]'

# Inspect a candidate's comments
curl -s -u "$P4USER:$TICKET" "$SWARM_URL/api/v11/reviews/<id>" | head -c 500
```

A good candidate is one that:

- Is in `needsReview` (or any non-terminal state).
- Has not been `p4 submit`-ed (no entries in `commits[]`).
- Has Greptile-authored inline comments already (visible in `/api/v11/comments/reviews/<id>` with `context.file` set on each row, plus the Greptile summary comment). Reviews whose first comment is the "Greptile Filter — Automatic reviews are disabled" banner have no inline transcript; either pick a different review or write a `.greptile` config with `{"skipReview":"NEVER"}` covering the test path before shelving (see gotcha 5).
- Has not already had `(reviewId, target-terminal-status)` deduped in Redis.

If none qualify, create a fresh review with a shelved CL containing intentionally review-worthy code. The scratch dir `~/p4-scratch-dj` is the canonical place — see the `perforce-dev` skill for workspace setup. Greptile auto-reviews on shelve as long as the merged config doesn't say `skipReview: AUTOMATIC` for the changed files; you do not need to post an `@greptile` mention.

### 3. Transition to terminal

```bash
# To archive (maps to parser action "closed"):
curl -s -u "$P4USER:$TICKET" -X POST -H 'Content-Type: application/json' \
  -d '{"transition":"archived"}' \
  "$SWARM_URL/api/v11/reviews/<id>/transitions"

# To reject (also maps to "closed", different dedup combo from archived):
curl -s -u "$P4USER:$TICKET" -X POST -H 'Content-Type: application/json' \
  -d '{"transition":"rejected"}' \
  "$SWARM_URL/api/v11/reviews/<id>/transitions"
```

### 4. Watch the log

```bash
# Wait for the state poller to pick it up (≤30s cadence)
until grep -q "reviewId.*: <id>" <gdev-log>; do sleep 5; done
grep -A 6 "Pushed Swarm state transition" <gdev-log> | tail -12
```

Then look for the worker side:

```bash
CORR_ID=<from-pushed-line>
grep "$CORR_ID" <gdev-log> | grep -iE "learn|memor|no review comments|task completed|skipping"
```

Expected good outcomes:

| Worker log line | Meaning |
|---|---|
| `learn task completed` with `memoriesLearned: N` | Real learning produced (rare without setup from gotcha 5) |
| `No review comments to learn from` | Pipeline OK, review had no inline transcript |
| `Skipping post-commit review` | Pipeline OK, business rule from gotcha 4 |

Anything that looks like a thrown exception (`Failed to fetch review`, `Changelist N has no files`, etc.) is a regression to debug.

### 5. Verify memory rows (only meaningful if learn ran with content)

```bash
psql "$DATABASE_URL" -c \
  "select id, type, status, score, created_at from \"Memory\" where created_at > now() - interval '5 minutes' order by created_at desc;"
```

`DATABASE_URL` should be the `greptile-perforce` DB when on `perforce_on_worker` branch (the zsh hook flips this).

## Out of scope (use other skills)

- General Perforce env / p4 CLI work → `perforce-dev` skill.
- Greptile review *output* quality (prompts, agent behavior) → not this skill.
- Changes to the Swarm pollers themselves (e.g. cadence, new event types) → modify `apps/webhook/src/swarm-polling.ts` or `swarm-state-polling.ts`, then come back here to verify.

## Related files

| Path | Role |
|---|---|
| `apps/webhook/src/swarm-state-polling.ts` | State-change poller that emits the synthetic event |
| `apps/webhook/src/swarm-polling.ts` | Comment poller (sibling) |
| `apps/worker/src/steps/filter.ts:758-763` | Post-commit skip rule |
| `apps/worker/src/steps/learn.ts:420-490` | Perforce single-Review collapse + procedural-memory call |
| `packages/scm/src/platforms/perforce/types.ts` | `PerforceEvent` / `PerforceStateEvent` types |
| `docs/content/design/perforce-fake-webhook.md` | Architecture rationale |
