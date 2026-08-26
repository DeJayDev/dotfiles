---
name: perforce
description: >
  Use when working with Perforce / P4 (the version control system formerly called
  Helix Core) or its code review tool P4 Code Review (formerly Helix Swarm).
  Triggers on: p4, perforce, helix core, helix swarm, swarm, "p4 code review",
  depot, changelist / CL, workspace / client, shelve, p4 submit, p4 edit, p4 sync,
  streams, .p4config, P4PORT, a review URL like swarm/12345, or porting a git
  mental model to perforce. Covers the core CLI, the centralized mental model that
  trips up git users, and the shelve -> #review -> approve code review lifecycle.
---

# Perforce (P4) and P4 Code Review

Read this whole file. Then load a reference file only if the task needs it.
The whole point of this skill is that the obvious git intuition is wrong here,
so do not trust your priors about "checkout", "branch", "stash", or "commit".

## Naming (this changed in 2025 -- get it right)

In January 2025 Perforce rebranded the whole line under the **P4 Platform**.
The current names are what you must use:

| Old name        | Current name      | Notes                                  |
| --------------- | ----------------- | -------------------------------------- |
| Helix Core      | **P4**            | the server + VCS. Server daemon still `p4d`, CLI still `p4`. |
| Helix Swarm     | **P4 Code Review**| the web review tool. People still say "Swarm". |
| Helix Core Cloud| P4 Cloud          |                                        |
| Helix DAM       | P4 DAM            | digital asset management               |
| Helix Plan      | P4 Plan           |                                        |
| Helix Search    | P4 Search         |                                        |

The binaries (`p4`, `p4d`), env vars (`P4PORT`, `P4USER`, `P4CLIENT`), config
files (`.p4config`), and the term "Swarm" in URLs/hostnames did **not** change.
So `swarm.example.com/12345` is a P4 Code Review URL. Don't "correct" it.

## Mental model: this is NOT git

Perforce is **centralized and server-side**. There is no local repo, no local
history, no staging area. The server is the source of truth and you are always
talking to it.

- **Depot** = the server-side repository of files. Paths look like
  `//depot/main/src/foo.c`. One server can host many depots.
- **Workspace** (aka **client**) = your local copy + a **mapping (View)** that
  says which depot paths land where on disk. Named, e.g. `dj-laptop-main`.
  Set via `P4CLIENT` or `p4 -c <client>`.
- **Changelist** (CL) = the atomic unit of work: a numbered group of opened
  files + a description. This is the closest thing to a commit, but it lives on
  the server and is created *before* you submit. `default` is the unnamed
  pending changelist.
- **`p4 submit`** = the only thing that writes to the depot (≈ `git commit` +
  `git push`, atomic, server-side, gets a global sequential CL number).

The footgun that breaks everyone: **you must tell the server before you edit a
file.** Files sync to disk **read-only**. Run `p4 edit <file>` (or `p4 add` /
`p4 delete`) to open it for change *first*. If you edited files outside P4
(common for an agent), reconcile them: `p4 status` or `p4 reconcile` opens the
diffs into a changelist. Don't just start writing -- the write may fail on a
read-only file, and even if it succeeds the server won't know about it.

## Core workflow (copy-paste)

```bash
p4 info                         # confirm connection: server, user, client, root
p4 sync                         # pull latest from depot into workspace (read-only on disk)
p4 edit //depot/main/foo.c      # open existing file for edit (makes it writable)
p4 add  newfile.c               # open a new file for add
p4 delete oldfile.c             # open for delete
# ...make your changes...
p4 status                       # detect files changed outside p4; opens them
p4 diff                         # diff opened files vs depot
p4 change                       # create/edit a numbered CL + description (opens $EDITOR)
p4 submit -c 12345              # commit the CL to the depot (atomic)
```

Inspecting things:

```bash
p4 opened                       # what files you currently have open, in which CL
p4 changes -m 10 //depot/main/...   # recent changelists on a path
p4 describe -du 12345           # full CL: description + unified diff
p4 filelog -m 5 //depot/main/foo.c  # revision history of one file
p4 annotate -u //depot/main/foo.c   # line-by-line blame (who/which CL)
p4 revert -a //depot/main/...   # discard unchanged opened files (-a = unchanged only)
```

**Agent tip:** add `-ztag` for stable key:value output (or `-G` for Python
marshal) when you need to parse. `cd` into the workspace (or pass `-c <client>`)
before every command -- P4 resolves the workspace from cwd/`.p4config`/env.

## p4 review is a TRAP

`p4 review` / `p4 reviews` are an **old changelist-counter / review-daemon**
command. They have **nothing to do with P4 Code Review**. Code review is driven
by the `#review` keyword and the web UI / its REST API, never by `p4 review`.

## Code review lifecycle (P4 Code Review / Swarm)

Two models:
- **Pre-commit** (the norm): review a **shelved** changelist before it hits the
  depot. Shelving caches your opened files on the server without submitting.
- **Post-commit**: review an already-**submitted** changelist.

Start a pre-commit review from the CLI by putting `#review` in the CL
description, then **shelving** (the order matters):

```bash
p4 edit //depot/main/foo.c
p4 change                       # description includes a line:  #review  @alice @@my-team
p4 shelve -c 12345              # shelve -> this is what kicks off the review
```

P4 Code Review then rewrites `#review` to `#review-67890` (67890 = the review
id, a *separate* changelist it manages). Key gotchas:

- Adding `#review` to a description **after** shelving does nothing -- you must
  **re-shelve** (`p4 shelve -r -c 12345`) to trigger it.
- Reviewers: `@user`, group `@@group`. Prefix `*` makes them **required**
  (`@*alice`, `@@*team`). `@@!group` = required but only one member must vote.
- To update a review: edit files, set description to `#review-67890`, re-shelve.
- Review **states**: *Needs review*, *Needs revision*, *Approved* (open or
  closed), *Rejected*, *Archived*. Approve is gated on required-reviewer votes.
  After approval a pre-commit review still needs a **Commit** (or
  "Approve and commit"). API/config tokens: `needsReview`, `needsRevision`,
  `approved`, `approved:commit`, `rejected`, `archived`.
- Quick URL to any change or review: `https://<swarm-host>/<id>`.

For the REST API, webhooks, voting rules, and workflow enforcement, read
`references/code-review.md`.

## When stuck

- Connection/identity wrong → `p4 info`, check `P4PORT P4USER P4CLIENT` and
  any `.p4config` in the tree.
- "file(s) not on client" / "not under client's root" → workspace **View**
  doesn't map that depot path. `p4 client -o` to inspect the mapping.
- Edited a file but P4 ignores it → you never opened it. `p4 status` /
  `p4 reconcile`.
- Need a ticket-based login → `p4 login` (interactive; ask the user to run it).

## References

- `references/cli-cheatsheet.md` -- fuller command list (sync/resolve, streams, shelve, diff2, integrate/merge, jobs, fixing mistakes).
- `references/code-review.md` -- P4 Code Review deep dive: models, states, REST API endpoints, webhooks, required reviewers, workflow rules.
- `references/git-to-p4.md` -- side-by-side git→p4 command translation for porting your intuition.
- `references/git-p4-bridge.md` -- the `git p4` bridge tool: using Git locally against a P4 depot (clone/sync/rebase/submit) and its footguns.
