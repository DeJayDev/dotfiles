# git-p4: the Git <-> Perforce bridge tool

This is a real tool, not a metaphor. `git p4` (older spelling `git-p4`) is a
Python script that ships with Git (`contrib/fast-import/git-p4`, exposed as the
top-level `git p4` subcommand since ~2014). It lets you use Git locally against
a Perforce depot. Distinct from `references/git-to-p4.md`, which is just a
command-translation table for working in raw `p4`.

## What it is

- **Client-side only.** Runs inside your Git repo, shells out to the `p4` CLI
  behind the scenes. No server reconfiguration, no admin access needed -- just
  P4 user credentials and the `p4` binary on `PATH`.
- **Two-way bridge.** Import P4 -> Git, and submit Git -> P4.
- Needs the usual P4 env (`P4PORT`, `P4USER`, and a `p4 login` ticket).
- Imported P4 content lands in `refs/remotes/p4/master`.

## Four commands

```bash
git p4 clone //depot/path/project [dest]   # new git repo from a depot path
git p4 sync                                 # pull new p4 changes -> new git commits
git p4 rebase                               # sync + rebase current branch onto p4/master
git p4 submit                               # turn git commits into p4 changelists and submit
```

## Clone: mind the history depth

By default clone imports only the **head** revision (shallow) -- fast, small.

```bash
git p4 clone //depot/path/project              # head only
git p4 clone //depot/path/project@all          # FULL history (slow, large)
git p4 clone //depot/path/project@1000,2000    # changelist range
git p4 clone --detect-branches //depot/proj@all  # map p4 branch specs -> git branches
```

To add a depot to an existing git repo, use `sync` not `clone` (clone won't run
on a populated repo):

```bash
git init && git p4 sync //depot/path     # imports into refs/remotes/p4/master
git p4 sync --branch=refs/remotes/p4/foo //depot/other
```

## Submit: the part with sharp edges

Submitting needs a **separate p4 client workspace** (git-p4 applies each patch
there and runs `p4 submit`). Point it via `P4CLIENT` or git config
`git-p4.client`; git-p4 creates/populates the client root if missing.

```bash
git p4 rebase            # ALWAYS rebase first: get latest p4, linearize on top
git p4 submit            # each git commit between p4/master and HEAD -> one p4 CL
git p4 submit topicbranch
git p4 submit --commit <sha1>           # one commit
git p4 submit --commit <sha1>..<sha2>   # a range
git p4 submit -n         # dry run
```

Hard rules:
- **Always `git p4 rebase` before `git p4 submit`.** Submit only works if your
  commits sit linearly on top of `p4/master`. This is the standard footgun.
- **No merge commits.** git-p4 cannot translate a merge to a P4 changelist.
  History must be linear -- squash/rebase first (interactive rebase) if you have
  merges or want N git commits to become one CL.
- **One git commit = one P4 changelist.** The git commit message becomes the CL
  description.
- Conflicts on submit surface as normal P4 `p4 resolve` work in the p4 client;
  resolve, then re-run `git p4 submit`.

## Caveats worth knowing

- `--use-client-spec` (honor the workspace View on import) is documented as
  **untested/buggy** -- can drop files or mishandle exclude mappings. Avoid
  unless you must.
- Shallow clone + multiple branches don't mix -- for several branches of a big
  project, `git p4 clone` once per branch.
- If git-p4 state gets tangled (it can), re-cloning is often faster than
  untangling. Park unsubmitted work first (e.g. `p4 reconcile` / patches).

## When to recommend it vs raw p4

- Use **git-p4** when the user wants a local git workflow (branches, local
  commits, rebase) but the team's source of truth is a P4 depot they don't
  control.
- Use **raw `p4`** (the rest of this skill) when they're a normal P4 user, when
  shelve-based **P4 Code Review** is in play, or when they need streams /
  exclusive locks / per-file P4 features git-p4 doesn't model.

Docs: https://git-scm.com/docs/git-p4
