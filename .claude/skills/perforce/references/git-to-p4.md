# git -> P4 translation

For porting git intuition when working in **raw `p4`**. The mappings are
approximate -- read the "why it's different" notes, because several have no real
equivalent and silently doing the git thing produces wrong results.

If the user actually wants to drive P4 *through* Git (local branches, commits,
rebase, then push to the depot), they want the **git-p4 bridge tool**, not these
manual translations -- see `git-p4-bridge.md`.

## Concept map

| git                       | Perforce (P4)                          |
| ------------------------- | -------------------------------------- |
| remote repo               | depot (`//depot/...`) on the server    |
| local clone               | workspace / client (mapping + local files) |
| `.git/` local history     | nothing local -- history lives on the server |
| staging area / index      | a pending changelist (`p4 opened`)     |
| commit                    | submitted changelist (server-side, atomic, global number) |
| commit message            | changelist description                  |
| branch                    | a stream, or a branch spec + integrate, or a separate depot path |
| stash                     | shelve (but does NOT clean your tree)   |
| `.gitignore`              | `P4IGNORE` file                         |
| PR / merge request        | a P4 Code Review review                  |

## Command map

| git                         | P4                                              |
| --------------------------- | ----------------------------------------------- |
| `git clone`                 | `p4 client` (define workspace) then `p4 sync`   |
| `git pull` / `git fetch`    | `p4 sync` (or `p4 update`, which is safer)       |
| `git checkout <file>` (edit)| `p4 edit <file>`  ← REQUIRED before editing      |
| `git add <newfile>`         | `p4 add <file>`                                 |
| `git rm`                    | `p4 delete`                                     |
| `git mv`                    | `p4 move`                                        |
| `git add -A` (pick up edits)| `p4 reconcile` / `p4 status`                    |
| `git status`                | `p4 opened` + `p4 status`                        |
| `git diff`                  | `p4 diff` (workspace) / `p4 diff2` (two revs)   |
| `git commit`                | `p4 change` (write CL) -- not yet on server     |
| `git commit && git push`    | `p4 submit`                                      |
| `git stash` / `pop`         | `p4 shelve` / `p4 unshelve`                      |
| `git log <file>`            | `p4 filelog <file>` / `p4 changes <file>`       |
| `git show <rev>`            | `p4 describe -du <CL>` / `p4 print <file>@<rev>`|
| `git blame`                 | `p4 annotate -u`                                |
| `git checkout .` (discard)  | `p4 revert` (DESTRUCTIVE on disk)               |
| `git reset --hard`          | `p4 clean` / `p4 revert -a` (DESTRUCTIVE)       |
| `git merge` / `rebase`      | `p4 integrate`/`p4 merge` + `p4 resolve`        |
| `git branch -a`             | `p4 streams` / list branch specs / `p4 dirs`    |
| open a PR                   | put `#review` in the CL desc, then `p4 shelve`  |

## Why it's different (the parts that bite)

- **You must open files before editing.** Synced files are read-only.
  `git` lets you edit anything; P4 needs `p4 edit`/`add`/`delete` first, or a
  later `p4 reconcile`/`p4 status` to detect what you changed. An agent that
  just writes files will hit read-only errors or an out-of-sync server.
- **No local commits.** A changelist isn't "committed" until `p4 submit`, which
  goes straight to the shared depot. There is no local history to amend or
  rebase. To park work, **shelve** it.
- **Shelve != stash.** `p4 shelve` copies opened files to the server but leaves
  your workspace exactly as is. To get a clean tree you must also `p4 revert`.
- **The CL is the unit, and the number is global.** Changelist 4711 is server-
  wide and sequential, not per-file or per-branch. It can be renumbered on
  submit.
- **Branching is heavier.** A "branch" is often a different depot path (a stream
  or a classic branch spec). Cross-branch changes flow via
  `integrate`/`merge`/`copy` + `resolve` + `submit`, not a quick local checkout.
- **Conflicts resolve at submit/integrate time** via `p4 resolve`, not at pull
  time the way `git merge` does it.
- **Reverting is destructive to disk** -- `p4 revert`/`p4 clean` overwrite local
  files. Confirm before running on a user's tree.
