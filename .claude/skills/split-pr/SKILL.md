---
name: split-pr
description: >
  Splits a messy working tree or staging area into clean, focused commits or branches.
  Analyzes changed files, groups them by logical concern, and creates separate commits
  (or branches if requested). Use when changes got mixed together and need untangling
  before a PR.
allowed-tools: Bash(git:*)
argument-hint: "[optional hint, e.g. \"split out the auth changes from the refactor\"]"
---

# Split PR

Analyze the current working tree and staging area, group changes by logical concern, and split them into clean commits or branches.

## Inputs

- **$ARGUMENTS** (optional): Description of how to split, or specific grouping instructions. If empty, infer groupings automatically.

## Instructions

### 1. Survey the current state

```bash
git status
git diff --stat HEAD
git diff --cached --stat
```

If the tree is clean, tell the user and stop.

### 2. Understand the changes

For each changed file, read enough to understand what it does and why it changed:
- What module/concern does it belong to?
- Is this a feature, refactor, fix, config change, or infra change?
- Does it depend on or relate to other changed files?

Group files into logical clusters. Common splits:
- New feature vs. unrelated refactor
- App code vs. package/library code
- Config/infra vs. app logic
- One feature vs. another feature
- Dependency updates vs. code changes

If the user provided split instructions in $ARGUMENTS, use those instead of inferring.

### 3. Confirm the plan

Present the proposed groupings clearly before doing anything:

```
Group 1: "feat: discord-framework package"
  packages/discord-framework/src/types.ts
  packages/discord-framework/src/loader.ts
  packages/discord-framework/package.json

Group 2: "chore: biome config stubs"
  packages/types/biome.json
  packages/utils/biome.json

Group 3: "refactor: bot command migration"
  apps/bot/src/commands/ping.ts
  apps/bot/src/index.ts
```

Ask the user to confirm or adjust before proceeding.

### 4. Execute the split

**If splitting into commits on the current branch** (default):

1. Unstage everything: `git reset HEAD`
2. For each group in order:
   - Stage only the files for that group: `git add <files>`
   - Commit with the proposed message
3. Any leftover unstaged files remain as working tree changes.

**If splitting into separate branches** (when user asks for this or when groups are large/independent):

1. Note the current branch name and HEAD.
2. For each group:
   - Create a new branch from the base: `git checkout -b <branch-name> <base>`
   - Cherry-pick or re-stage only the relevant files
   - Commit
3. Return to the original branch.

### 5. Verify

```bash
git log --oneline -10
git status
```

Show the user the resulting commit log and any remaining uncommitted changes.

## Notes

- Never force-push or modify commits already on a remote branch without asking.
- If there are merge conflicts or ambiguous file ownership, stop and ask rather than guessing.
- Prefer fewer, cleaner commits over many micro-commits.
- Unstaged files that don't belong to any group should stay unstaged — don't commit them silently.
