---
name: sync-branch
description: >
  Brings the current branch up to date with its base by merging the latest base into
  it. Does reconnaissance first (what's coming in, what's likely to conflict, why each
  side changed), then merges with proper 3-way context on every conflict. Stops before
  pushing. Use when a feature branch is behind main/master and needs to be caught up,
  especially before opening or updating a PR.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(bun:*), Bash(pnpm:*), Bash(npm:*), Bash(yarn:*), Read, Edit, Grep, Glob
---

# Sync Branch

Merge the latest base into the current branch *with eyes open*. Understand the incoming changes, predict the conflict zones, resolve each conflict with 3-way context and knowledge of why each side wrote what it wrote, and verify before handing off.

The cardinal rule: **do not treat a conflict as a text problem.** A conflict is two intents meeting. Resolve the intent, then encode it. If you cannot articulate both intents in plain English, you cannot resolve the conflict yet.

## Inputs

- **$ARGUMENTS** (optional): Override the base branch (e.g. `develop`). If empty, infer from the remote default branch.

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

### 3. Fetch and report the gap

```bash
git fetch origin
git rev-list --left-right --count origin/<base>...HEAD
```

Tell the user how many commits behind and ahead they are. If behind is 0, stop — nothing to do. If ahead is 0, this is a pure fast-forward; note that and proceed.

### 4. Reconnaissance — understand both sides BEFORE merging

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

### 5. Start the merge

```bash
git merge --no-ff --no-commit origin/<base>
```

`--no-commit` gives you a chance to inspect a clean merge before it's recorded. `--no-ff` is optional — drop it if the repo prefers fast-forwards.

- Clean merge: run step 7 (verify), then `git commit` with the default message and jump to step 8.
- Fast-forward (no merge commit needed): nothing to resolve, run step 7 and step 8.
- Conflicts: go to step 6.

### 6. Resolve conflicts — with 3-way context, not text-level pattern matching

For the whole merge (not per-commit), work through every conflicted file:

```bash
git diff --name-only --diff-filter=U
```

For each conflicted file, follow this loop. **Do not skip the 3-way read.**

**6a. Read all three versions from the index.** The working tree only shows ours-vs-theirs; the merge base is what tells you *who changed what*:

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

For a deleted-on-one-side file: one of `:2:` or `:3:` will be missing. That's not a text conflict — it's a policy question (kept the delete, or restore and re-edit?). Ask the user.

**6b. Read the commits behind each side's change.** Knowing *why* a side changed is what lets you write a non-sloppy resolution:

```bash
git log -p HEAD..origin/<base> -- <file>   # their commits touching this file
git log -p origin/<base>..HEAD -- <file>   # our commits touching this file
```

If a commit's message is too thin, read the surrounding code or the PR (`gh pr list --search <sha>` if the project uses GitHub).

**6c. State the resolution plan in plain English before editing.** For each conflict hunk, write down (in your head or to the user, depending on risk) two sentences: "Ours changed X because Y. Theirs changed X because Z. The resolution is W, because it preserves both intents / chooses Y over Z for reason R."

If you can't write those two sentences, stop and ask the user. *This is the step the old version of this skill skipped, and it's why "blindly run the merge" produced sloppy results.*

**6d. Edit the file.** Now apply the resolution. Remove all conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`). Do not leave any marker, even commented out.

For generated files (lockfiles, build artifacts, generated types):
- Don't hand-merge. Resolve by regenerating from the merged source of truth.
- `bun.lock` / `bun.lockb` → `bun install`
- `pnpm-lock.yaml` → `pnpm install`
- `package-lock.json` → `npm install`
- `yarn.lock` → `yarn install`
- Generated code (Prisma, GraphQL codegen, OpenAPI): run the project's codegen command.

**6e. Sanity-check the resolution before staging.** Cheap checks that catch most "you merged text but broke the code" mistakes:

```bash
grep -nE '^(<<<<<<<|=======|>>>>>>>)' <file>   # any markers left?
```

Then read the resolved file (the whole file, not just the conflict region) and ask:
- Are all imports/uses of symbols introduced or renamed by either side still consistent?
- Did one side rename a function and the other add a new caller of the old name?
- Did one side change a signature and the other add a call site using the old signature?
- Are there now duplicate definitions, duplicate imports, or unreachable branches?

These are the failure modes that pass `git status` clean but break the build. Cross-file consequences matter too: if either side renamed an exported symbol, grep the repo for stragglers.

**6f. Stage:** `git add <file>`

**6g. After all files are resolved**, run the verify step (step 7) *before* committing. Then:

```bash
git commit   # accept default merge message unless the user asked otherwise
```

To bail out at any point: `git merge --abort` (restores the pre-merge state, including `--no-commit` mode).

### 7. Verify

```bash
git status                # nothing unmerged, nothing accidentally unstaged
git diff --cached --stat  # what's in the merge commit
git log --oneline -5
```

If the repo has a typecheck/build/lint/test command, run it now — this catches semantic breakage that text-level resolution missed. Common entry points: `bun run typecheck`, `pnpm typecheck`, `npm run build`, `cargo check`, `go build ./...`, `tsc --noEmit`. Read `package.json` / `Makefile` / `justfile` if unsure.

If verification fails: fix forward inside the merge (edit, `git add`, retry verify). Don't commit a broken merge.

### 8. Restore stashed work

If you stashed in step 1: `git stash pop`. If the pop conflicts, resolve with the same 3-way discipline as step 6 and tell the user.

### 9. Hand off

Print the push command and stop. Do NOT push.

```
Merge complete. To update the remote:

    git push
```

If the branch tracks a remote whose history would be rewritten (shouldn't happen with a merge, but check), warn the user.

## Notes

- Never push automatically. Always stop at step 9 and hand the command to the user.
- A merge commit is authored by the user performing the merge, but every other commit keeps its original author — no one else's work gets attributed to the user.
- If the repo requires linear history (no merge commits), tell the user and ask whether to switch to rebase. Rebase changes the resolution model (one conflict per replayed commit, not one for the whole range) — re-read step 6 with that in mind.
- For generated files, regenerate; don't hand-merge.
- The reconnaissance in step 4 is not optional. Skipping it is what the old version of this skill did, and it's what "sloppy" means in this context.
