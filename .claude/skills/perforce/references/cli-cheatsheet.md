# P4 CLI cheat sheet

Global options (go before the command): `p4 -c <client> -u <user> -p <port> -ztag <cmd>`.
`-ztag` = parseable key:value lines. `-G` = Python marshal (best for scripts).
`-Mj`/`p4 -ztag -Mj <cmd>` patterns vary by version; prefer `-ztag` for agents.

## Connection / identity
```bash
p4 info                  # server, user, client, root, server version
p4 set                   # show P4PORT/P4USER/P4CLIENT etc. (and where set)
p4 login                 # ticket login (interactive); p4 login -s = check status
p4 tickets               # list current tickets
p4 clients -u <user>     # workspaces owned by a user
p4 client -o [name]      # print a workspace spec (the View mapping lives here)
p4 client                # create/edit current workspace ($EDITOR)
```

## Sync (get files)
```bash
p4 sync                          # bring whole workspace to head
p4 sync //depot/main/...@12345   # sync a path to a specific changelist
p4 sync -n ...                   # preview (no changes)
p4 sync -f ...                   # force re-sync (re-pull even if "have" says current)
p4 have //depot/main/foo.c       # what revision the server thinks you have
p4 update                        # like sync but checks for local edits first (safer)
```

## Open / change files
```bash
p4 edit   -c 12345 file...       # open for edit in CL 12345
p4 add    -c 12345 file...       # open new files for add
p4 delete -c 12345 file...       # open for delete
p4 move   -c 12345 src dst       # rename/move (open old for delete, new for add)
p4 reopen -c 12345 file...       # move opened files to another CL
p4 revert file...                # discard changes, close file (DESTRUCTIVE on disk)
p4 revert -a                     # revert only files that are unchanged vs depot
```

## Reconcile work done outside P4
```bash
p4 status                        # preview: what would be opened (add/edit/delete)
p4 reconcile                     # actually open the detected diffs into a CL
p4 reconcile -n ...              # preview
p4 clean                         # make workspace match depot (DESTRUCTIVE: undoes local)
```

## Changelists
```bash
p4 change                        # create/edit a numbered CL (default has no number)
p4 change 12345                  # edit description of CL 12345
p4 changes -m 20 //depot/main/...        # recent submitted CLs on a path
p4 changes -s pending -u <user>          # your pending CLs
p4 changes -s shelved -u <user>          # your shelved CLs
p4 describe -du 12345            # CL description + unified diff
p4 describe -s 12345             # description + file list only (no diff), fast
p4 opened [-a] [file...]         # files open (in your client; -a = all clients)
```

## Diff
```bash
p4 diff   -du file...                 # opened file vs the rev you have (workspace)
p4 diff2 -u //path@1 //path@2         # server-side diff of two depot revisions
p4 diff2 -u //depot/a/... //depot/b/... # diff two branches/paths
```

## Shelve (server-side stash; also the basis of pre-commit review)
```bash
p4 shelve -c 12345               # shelve opened files in CL 12345
p4 shelve -r -c 12345            # replace shelf with current opened files (re-shelve)
p4 unshelve -s 12345 -c 67890    # pull a shelf into a CL (your workspace files stay!)
p4 shelve -d -c 12345            # delete the shelf
```
Note: unlike `git stash`, shelving does **not** revert your local files. Revert
separately if you want a clean tree.

## Submit
```bash
p4 submit -c 12345               # submit a numbered CL (atomic)
p4 submit -d "message" file...   # submit default-CL files with a message
p4 submit -e 12345               # submit an already-shelved CL without re-transfer
```

## Branching / merging
Two worlds. Older "classic" depots use branch specs + `p4 integrate`. Newer
setups use **streams** (`//streamdepot/main`, `//streamdepot/dev`).
```bash
p4 integrate -b <branchspec> //src/... //tgt/...   # classic merge (schedule)
p4 merge //src/... //tgt/...     # merge changes down/across
p4 copy  //src/... //tgt/...     # copy (no merge; make target identical)
p4 resolve -as                   # auto-resolve safe (no conflicts)
p4 resolve -am                   # auto-merge
p4 resolve                       # interactive resolve of conflicts
p4 streams //streamdepot/...     # list streams
p4 switch <stream>               # (DVCS/stream) switch workspace to a stream
```
After integrate/merge/copy you still `p4 resolve` then `p4 submit`.

## History / blame
```bash
p4 filelog -m 10 //depot/main/foo.c   # revision history of a file
p4 annotate -u //depot/main/foo.c     # line-by-line author/CL (git blame)
p4 print //depot/main/foo.c@12345     # dump a file's content at a revision
p4 changes //depot/main/foo.c         # CLs that touched the file
```

## Jobs (bug/issue tracking integration)
```bash
p4 jobs                          # list jobs
p4 fix -c 12345 job000123        # link a job to a changelist
```

## Undo / fix mistakes
```bash
p4 revert file...                # abandon opened changes (before submit)
p4 shelve + p4 revert            # park work without losing it
p4 undo //depot/main/foo.c@12345 # open a change that undoes a submitted revision
p4 obliterate ...                # PERMANENT depot removal -- admin only, never run casually
```

## Things that will bite you
- Files land **read-only**; `p4 edit` toggles the write bit. An editor that
  can't write means the file isn't open.
- `cwd` matters: P4 finds the workspace from cwd + `.p4config` + env each call.
  In a tool that resets cwd, prefix each command (`cd <ws> && p4 ...`).
- `p4 revert` and `p4 clean` change files on disk -- they're destructive. Ask
  before running them on someone's tree.
- A CL number is **global and sequential** across the server, not per-file.
- Exclusive-locked filetypes (`+l`) let only one person open a file for edit.
