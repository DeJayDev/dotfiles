---
name: cleanup
description: Big cleanup pass on a file or folder, together. Loads Ponytail, dedupes, deletes dead code, de-weirds patterns.
disable-model-invocation: true
argument-hint: "[file or folder, in plain words]"
---

# Cleanup Sweep

Target, as the user typed it: **$ARGUMENTS**

Read the file or folder out of that line however it is phrased ("let's do the
providers/perforce folder", "deslop cloning.ts"). If there is no target, ask
which file or folder in one line and stop.

This is a maintainability pass, not a feature change, and it is done together:
the user vetoes as you go, so post wins early and keep moving.

## 1. Load the rules

- Invoke the **ponytail** skill with the Skill tool (listed as `ponytail` or
  `ponytail:ponytail`). This sweep is Ponytail's ladder applied to existing
  code: delete over add, reuse what exists, no speculative abstraction. If it
  is not installed, apply those reflexes yourself.
- Read `~/.claude/CLAUDE.md` and follow it. The sweep runs on top of it.
- Read `${CLAUDE_SKILL_DIR}/practices.md`: the hunt list, the helper weight
  rule, and the rules of engagement. All of it applies to the target.

## 2. Read, scan, then edit

Trace the target's real flow end to end before editing. Start in the named
file. The surrounding package is in scope once the file is done. Anything past
that package is the user's call; ask before wandering further, except where a
dedup or caller fix-up genuinely requires touching another file.

For a whole folder, `ponytail-audit` on it (if installed) produces a ranked
cut-list worth starting from.

Post the cut-list as one line per item: location, what to cut, what replaces
it. Then start applying immediately. Invoking this skill is the user's
permission to edit the working tree; do not wait for per-item approval. It is
not permission to commit, branch, push, or open a PR; those still get asked
for, per CLAUDE.md.

Hold, and ask, only on what `practices.md` says to hold.
