---
name: sync-branch
description: >
  Brings the current branch up to date with its base, either by merging the base in or by
  replaying your commits on top of it. Does reconnaissance first (what's coming in, what's
  likely to conflict, whether the branch is dragging along commits the base doesn't want),
  then resolves every conflict with proper 3-way context. Stops before pushing. Use when a
  feature branch is behind main/master/a release branch and needs to be caught up,
  especially before opening or updating a PR.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(bun:*), Bash(pnpm:*), Bash(npm:*), Bash(yarn:*), Read, Edit, Grep, Glob
---

# Sync Branch

Bring the base into the current branch *with eyes open*. Understand the incoming changes, predict the conflict zones, resolve each conflict with 3-way context and knowledge of why each side wrote what it wrote, and verify before handing off.

The cardinal rule: **do not treat a conflict as a text problem.** A conflict is two intents meeting. Resolve the intent, then encode it. If you cannot articulate both intents in plain English, you cannot resolve the conflict yet.

The second rule: **a sync is not always a merge.** Merging the base in preserves whatever the branch already dragged along. Sometimes what the branch dragged along is exactly the problem. Step 4e is how you find out, and step 5 is where you choose.

## Inputs

- **$ARGUMENTS** (optional):
  - A base branch to override detection (e.g. `develop`, `release/2026-aug`).
  - A strategy: `merge` or `replay`. If absent, pick per step 5.
  - Both may be given together (e.g. `release/2026-aug replay`).

## Instructions

### 1. Precondition checks

```bash
git rev-parse --abbrev-ref HEAD
git status --porcelain
```

- If on `main` / `master` / `develop` / the detected base: stop and tell the user.
- If the working tree is dirty: ask the user whether to stash (`git stash push -u`) or abort. Don't stash silently.
- If a merge/rebase is already in progress (`.git/MERGE_HEAD` or `.git/rebase-*` exists): stop and tell the user — don't compound state.

### 2. Resolve the base branch

If $ARGUMENTS provides a base, use it. Otherwise detect:

```bash
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
```

Fall back to `main` if that fails.

Confirm the ref actually exists before relying on it (`git rev-parse --verify origin/<base>`). A base that is a release branch rather than the repo default is a strong hint to pay close attention to step 4e.

### 3. Fetch and report the gap

```bash
git fetch origin
git rev-list --left-right --count origin/<base>...HEAD
```

Tell the user how many commits behind and ahead they are. If behind is 0, stop — nothing to do. If ahead is 0, this is a pure fast-forward; note that and proceed.

### 4. Reconnaissance — understand both sides BEFORE touching anything

This step is the difference between a careful sync and a sloppy one. Skip nothing here.

**4a. What's coming in from base?** List the incoming commits and skim their messages and shape:

```bash
git log --oneline --no-merges HEAD..origin/<base>
git diff --stat HEAD...origin/<base>
```

Group the incoming work mentally: refactors, feature additions, dependency bumps, renames, deletions. If a commit message is opaque, read its diff (`git show <sha>`). The goal is to be able to summarize *what changed on base* in two or three sentences before merging.

**4b. What's on your branch?** Same treatment for the local side:

```bash
git log --oneline --no-merges origin/<base>..HEAD
git diff --stat origin/<base>...HEAD
```

**4c. Predict conflict zones.** Files touched by both sides are conflict candidates:

```bash
git diff --name-only HEAD...origin/<base> | sort > /tmp/sync-base-files
git diff --name-only origin/<base>...HEAD | sort > /tmp/sync-ours-files
comm -12 /tmp/sync-base-files /tmp/sync-ours-files
```

Not every overlap will conflict (git auto-merges non-overlapping hunks), but every conflict will be in this list. For each file in the intersection, look at both sides' changes *now*, before the merge muddies the working copy:

```bash
git log --oneline HEAD..origin/<base> -- <file>
git log --oneline origin/<base>..HEAD -- <file>
```

Report the intersection to the user with a one-line guess at each file's risk (e.g. "lockfile — regenerate", "both sides edited the same function — needs manual merge", "rename on base vs edit on ours — careful").

**4d. Detect rename/delete hazards.** Renames on one side combined with edits on the other are the classic silent-corruption case:

```bash
git diff --name-status --find-renames HEAD...origin/<base> | grep '^R'
git diff --name-status --find-renames origin/<base>...HEAD | grep '^R'
```

Cross-reference renames with the conflict-candidate list and flag any pairs to the user before continuing.

**4e. Is the branch dragging along commits the base doesn't have?** This decides step 5, and it is the step people skip.

```bash
git log --format='%h %an | %s' origin/<base>..HEAD   # who authored what's "yours"
git rev-list --left-right --count origin/<base>...origin/main   # is the base itself behind main?
```

Read the author column. **Commits by people other than the user are the tell.** They appear because the branch merged some *other* base (usually `main`) that the current base does not fully contain — so from the base's point of view, that third party's work is part of "your" PR and will ship when the PR merges.

This is common and easy to miss when the PR base is a release branch: a release branch is often *behind* its own upstream, and every commit in that gap becomes a stowaway on any branch that merged the upstream.

If you find foreign commits, say so explicitly before doing any work — name the commits, their authors, and what merging the PR would therefore land in the base. Retargeting a PR's base on GitHub does **not** remove them; it only changes what GitHub diffs against. Only rewriting the branch does.

### 5. Choose the strategy: merge or replay

If $ARGUMENTS named a strategy, use it. Otherwise:

- **Default to `merge`** — it's append-only and never rewrites pushed history.
- **Recommend `replay`** when 4e found foreign commits, or when the user wants the PR to contain only their own work. Present the tradeoff and let the user choose. Do not silently rewrite a pushed branch.

|  | `merge` (step 6) | `replay` (step 7) |
|---|---|---|
| History | append-only, adds a merge commit | rewrites the branch |
| Foreign commits from 4e | **kept** — they ship with the PR | **dropped** |
| Push | `git push` | `git push --force-with-lease` |
| Conflicts | one resolution for the whole range | one per replayed commit |

Both paths use the same conflict discipline (step 8) and the same verification (step 9).

### 6. Merge path

```bash
git merge --no-ff --no-commit origin/<base>
```

`--no-commit` gives you a chance to inspect a clean merge before it's recorded. `--no-ff` is optional — drop it if the repo prefers fast-forwards.

- Clean merge: run step 9 (verify), then `git commit` with the default message and jump to step 10.
- Fast-forward (no merge commit needed): nothing to resolve, run step 9 and step 10.
- Conflicts: go to step 8, then commit.

To bail out at any point: `git merge --abort` (restores the pre-merge state, including `--no-commit` mode).

### 7. Replay path

Replaying puts the user's own commits on top of the base tip and drops everything else — including merge commits and any foreign commits found in 4e.

**7a. Record the recovery point.** Print the current tip SHA and tell the user it is the undo. If the branch is pushed, the old tip also survives on the remote until the force-push.

```bash
git rev-parse HEAD   # recovery point — say this SHA out loud to the user
```

**7b. Identify the commits to replay.** The user's own non-merge commits, oldest first:

```bash
git log --reverse --no-merges --format='%h %an | %s' origin/<base>..HEAD
```

Exclude the foreign commits from 4e and every merge commit. Confirm the list with the user if there is any ambiguity about what counts as "their" work.

**7c. Reset onto the base and replay:**

```bash
git reset --hard origin/<base>
git cherry-pick <sha1> <sha2> ...   # oldest first
```

Resolve conflicts per step 8 as each one lands, then `git cherry-pick --continue`. To bail out: `git cherry-pick --abort`, then `git reset --hard <recovery SHA from 7a>`.

**7d. Re-resolve, don't reuse.** Conflicts here are against a *different* base than any earlier merge, so earlier resolutions are not automatically valid. Re-read the intents (step 8) rather than reapplying yesterday's answer from memory.

**7e. Regenerate, don't replay, generated files.** A cherry-picked lockfile is stale by construction — it was computed against the old base. Reset it to the base's version and regenerate from the merged manifests:

```bash
git checkout origin/<base> -- <lockfile>
<pkg-manager> install --lockfile-only    # then git add
```

**7f. Verify the result is actually clean.** The replayed branch should contain only the user's files:

```bash
git log --format='%h %an | %s' origin/<base>..HEAD   # only the user's commits?
git diff --stat origin/<base>..HEAD                  # only the user's files?
```

If a file the user never touched shows up here, a foreign commit survived — stop and investigate.

### 8. Resolve conflicts — with 3-way context, not text-level pattern matching

Work through every conflicted file:

```bash
git diff --name-only --diff-filter=U
```

For each conflicted file, follow this loop. **Do not skip the 3-way read.**

**8a. Read all three versions from the index.** The working tree only shows ours-vs-theirs; the merge base is what tells you *who changed what*:

```bash
git show :1:<file> > /tmp/sync-base.txt   # common ancestor (merge base)
git show :2:<file> > /tmp/sync-ours.txt   # HEAD / your branch
git show :3:<file> > /tmp/sync-theirs.txt # origin/<base> / incoming
```

Then compare each side against the base — these diffs are the *intents* you must preserve:

```bash
diff -u /tmp/sync-base.txt /tmp/sync-ours.txt    # what we changed
diff -u /tmp/sync-base.txt /tmp/sync-theirs.txt  # what they changed
```

Note: during a cherry-pick, `:2:` is the base-so-far and `:3:` is the commit being replayed — the sides are swapped relative to a merge. Read them, don't assume.

For a deleted-on-one-side file: one of `:2:` or `:3:` will be missing. That's not a text conflict — it's a policy question (keep the delete, or restore and re-edit?). Ask the user.

**8b. Read the commits behind each side's change.** Knowing *why* a side changed is what lets you write a non-sloppy resolution:

```bash
git log -p HEAD..origin/<base> -- <file>   # their commits touching this file
git log -p origin/<base>..HEAD -- <file>   # our commits touching this file
```

If a commit's message is too thin, read the surrounding code or the PR (`gh pr list --search <sha>` if the project uses GitHub).

**8c. State the resolution plan in plain English before editing.** For each conflict hunk, write down (in your head or to the user, depending on risk) two sentences: "Ours changed X because Y. Theirs changed X because Z. The resolution is W, because it preserves both intents / chooses Y over Z for reason R."

If you can't write those two sentences, stop and ask the user.

**8d. Edit the file.** Now apply the resolution. Remove all conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`). Do not leave any marker, even commented out.

For generated files (lockfiles, build artifacts, generated types):
- Don't hand-merge. Resolve by regenerating from the merged source of truth.
- `bun.lock` / `bun.lockb` → `bun install`
- `pnpm-lock.yaml` → `pnpm install`
- `package-lock.json` → `npm install`
- `yarn.lock` → `yarn install`
- Generated code (Prisma, GraphQL codegen, OpenAPI): run the project's codegen command.

**8e. Sanity-check the resolution before staging.** Cheap checks that catch most "you merged text but broke the code" mistakes:

```bash
grep -nE '^(<<<<<<<|=======|>>>>>>>)' <file>   # any markers left?
```

Then read the resolved file (the whole file, not just the conflict region) and ask:
- Are all imports/uses of symbols introduced or renamed by either side still consistent?
- Did one side rename a function and the other add a new caller of the old name?
- Did one side change a signature and the other add a call site using the old signature?
- Did one side *loosen or tighten a type* that the other side's new code depends on? (A helper added by one side, typed against the old side's schema, will not compile against a relaxed one.)
- Are there now duplicate definitions, duplicate imports, or unreachable branches?
- Did one side delete a symbol the other side still uses? **Grep the whole package, not just `src/`** — build scripts, config files, and tooling at the package root are easy to miss, and ambient/global type declarations have no import to follow.

These are the failure modes that pass `git status` clean but break the build.

**8f. Stage:** `git add <file>`

**8g. After all files are resolved**, run the verify step (step 9) *before* committing.

### 9. Verify

```bash
git status                # nothing unmerged, nothing accidentally unstaged
git diff --cached --stat  # what's about to be committed
git log --oneline -5
```

If the repo has a typecheck/build/lint/test command, run it now — this catches semantic breakage that text-level resolution missed. Common entry points: `bun run typecheck`, `pnpm typecheck`, `npm run build`, `cargo check`, `go build ./...`, `tsc --noEmit`. Read `package.json` / `Makefile` / `justfile` if unsure.

Two traps:

- **A passing build is not a passing typecheck.** Bundlers and loaders that strip types (`tsx`, `esbuild`, `swc`) will happily build code that `tsc --noEmit` rejects. If a package has both, run both.
- **Establish the baseline before blaming yourself.** If a check fails, determine whether it *already* failed on the base (`git stash` + check out the base, or reason from whether either side touched the files involved). Report pre-existing breakage as pre-existing; never silently "fix" it inside a sync, and never assume a red check means your resolution was wrong.

If verification fails because of the sync: fix forward (edit, `git add`, retry verify). Don't commit a broken sync.

Anything you fix that is *not* part of the sync belongs in its own commit, after the merge/replay commit — not folded into it.

### 10. Restore stashed work

If you stashed in step 1: `git stash pop`. If the pop conflicts, resolve with the same 3-way discipline as step 8 and tell the user.

### 11. Hand off

Print the push command and stop. Do NOT push.

Merge path:

```
Sync complete. To update the remote:

    git push
```

Replay path — the branch was rewritten, so say so plainly, and give the recovery SHA from 7a:

```
Branch rewritten on top of <base>. Old tip was <sha> (still on the remote until you push).

    git push --force-with-lease
```

## Notes

- Never push automatically. Always stop at step 11 and hand the command to the user.
- Never force-push without the user explicitly choosing the replay path.
- A merge commit is authored by the user performing the merge, but every other commit keeps its original author — no one else's work gets attributed to the user. That cuts both ways: foreign commits stay visibly foreign in `git log`, which is exactly what makes step 4e work.
- If the repo requires linear history (no merge commits), the replay path is the only option — say so rather than proposing a merge.
- For generated files, regenerate; don't hand-merge.
- The reconnaissance in step 4 is not optional. Skipping it is what "sloppy" means in this context.
