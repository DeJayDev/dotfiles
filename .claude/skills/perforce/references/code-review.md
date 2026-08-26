# P4 Code Review (formerly Helix Swarm) deep dive

Web tool that sits on top of a P4 server and manages reviews. People and URLs
still say "Swarm". A review is itself a server-side changelist that the tool
owns and updates -- separate from the author's changelist.

## Two models

- **Pre-commit**: review uncommitted work via a **shelved** changelist. Code is
  not in the depot yet; approval gates the commit. This is the default and the
  one most "code review" requests mean.
- **Post-commit**: review an already-**submitted** changelist. Doesn't block the
  author; review happens after the fact.

Internally: when a review starts, P4 Code Review creates a **review changelist**
and copies the author's shelved files into it. Every time the author re-shelves,
it copies the new files in and snapshots the old set as an **archive changelist**
-- that's how it gives you per-update diffs. The review changelist is never
actually submitted (pre-commit); committing empties it. The managing user is
usually a P4 user named `swarm` with admin privileges.

## Starting / updating a review from the CLI

Put the keyword in the changelist description, then shelve. The shelve (not the
description edit) is the trigger.

```bash
# create
p4 edit //depot/main/foo.c
p4 change            # description has a line:  #review  @alice @@*platform-team
p4 shelve -c 12345

# update an existing review 67890
p4 change 12345      # description line:  #review-67890
p4 shelve -r -c 12345
```

- `#review` is the default keyword; admins can customize it.
- After the review starts the tool rewrites `#review` -> `#review-<id>`.
- Adding `#review` after a shelve does nothing -- **re-shelve** to fire it.
- Reviewers in the description:
  - `@alice` user, `@@team` group.
  - `*` prefix = **required**: `@*alice`, `@@*team`.
  - `@@!team` = required group but only **one** member must vote.
- Stream-spec-only changelists won't pick up project default reviewers/rules --
  include a real file from the project path so the review associates to a project.
- Commit-edge deployments: shelved changes must be **promoted** to the commit
  server before a review can start (admin sets `dm.shelve.promote=1`, or promote
  manually). On an edge server an un-promoted shelf silently fails to start.

## States

| UI label        | API/config token   | Meaning                                            |
| --------------- | ------------------ | -------------------------------------------------- |
| Needs review    | `needsReview`      | started; awaiting review                           |
| Needs revision  | `needsRevision`    | reviewer wants changes                             |
| Approved        | `approved`         | passed; may still need a commit (open vs closed)   |
| Approve + commit| `approved:commit`  | approve and submit in one step (pre-commit only)   |
| Rejected        | `rejected`         | will not be committed                              |
| Archived        | `archived`         | filed away, neither approved nor rejected          |

- **Approve** is only offered once required-reviewer **voting** is satisfied.
- A pre-commit review, once approved, still needs **Commit** to land in the depot
  (or use Approve and commit).
- By default, if an approved review's files change again, it drops back to
  **Needs review** automatically.

## Comments, tasks, votes

- Reviewers comment on a file or a specific line; comments can be flagged as
  **tasks** the author must address before the review closes.
- Required reviewers **vote** up/down; vote rules decide when Approve unlocks.
- **Checklists** (if enabled) add pass/warn/fail items that can block approval.

## Workflow rules (enforcement)

Project/branch workflows control automation at key points:
- **On commit without a review**: Allow (default) / auto-Create a review / Reject.
- **On commit with a review**: Allow / "Reject unless approved" (submit only if
  the associated review is approved AND content matches).
- **On update of a review in an end state**: Allow / Reject (locks protected
  end states like `approved:commit`).
- **Automatic approval** based on vote count + non-blocking tests passing.
- **Blocking tests**: CI integrations can block approve/commit until green.

## REST API (the programmatic surface)

Two live API versions, and **they're meant to be mixed** -- this trips people
up. `v11` (since Swarm 2022.1) is the modern read surface (list/get reviews,
transitions, comments, vote, projects). `v9` still holds the **write**
operations that v11 never got: create a review, add a change, change state,
edit description. The docs explicitly recommend using v11 and falling back to
v9 for what v11 lacks. (`v10` also exists; prefer v11/v9.)

Auth: HTTP Basic with P4 `username:ticket` (get the ticket from `p4 login -p`).
If your HTTP client can't send PATCH, POST with `?_method=PATCH`.

Verified endpoints:

```
# --- read (v11) ---
GET   /api/v11/reviews                       # list/search: state[], project[], author, max, after, keywords[], fields[]
GET   /api/v11/reviews/{id}                  # one review: state, participants, commits, complexity...
GET   /api/v11/reviews/{id}/transitions      # READ-ONLY: which transitions are allowed + what's blocking approval
GET   /api/v11/reviews/{id}/files            # files changed (supports ?from=&to= between versions)
GET   /api/v11/reviews/{id}/activity
GET   /api/v11/comments/{topic}/{id}         # topic = reviews | changes | jobs   (e.g. .../comments/reviews/123)
GET   /api/v11/projects  ,  /api/v11/projects/{id}
GET   /api/version                           # installed version + supported apiVersions (no auth needed)

# --- write (v9) ---
POST  /api/v9/reviews            -d change=12345          # create a review from a changelist
POST  /api/v9/reviews/{id}/changes/  -d change=12346      # add/replace a changelist on a review
PATCH /api/v9/reviews/{id}/state  -d state=approved [-d commit=1]   # transition; commit=1 = Approve and Commit
PATCH /api/v9/reviews/{id}        -d description=...      # edit description
POST  /api/v9/reviews/{id}/vote/  -d "vote[value]=up"  [-d "vote[version]=N"]  # value: up | down | clear
# valid state= values: needsReview, needsRevision, approved, rejected, archived

# --- write (v11) ---
POST  /api/v11/comments/{topic}/{id}   -d body=...  [-d taskState=open]   # add comment (open = make it a task)
POST  /api/v11/comments/{commentId}/edit
```
Note the vote shape: it's a `v9` endpoint, the path ends in `/vote/` (trailing
slash), and the value goes in the **body** as `vote[value]`, not in the URL. To
find reviews you've voted on, list with `?hasVoted=up` (or `down`).

State changes are gated by role: only **moderators** (or super users) can
approve/reject; author/project members can move between needsReview /
needsRevision / archived. `GET .../transitions` tells you what *you* are allowed
to do and what's blocking (required votes, failing tests) -- check it before
attempting a PATCH.

Exact shapes still drift across releases; confirm against the running instance's
docs (the version is in the URL, e.g. `.../swarm/2026.1/...`) before scripting.
First, hit `/api/version` -- it needs no auth and tells you exactly what's there.
Real response from a current (2025.5) instance:

```json
{"apiVersions":[9,10,11],"version":"P4 Code Review/2025.5/2869592 (2025/12/17)","year":"2025"}
```

Note `apiVersions` lists `[9,10,11]` -- all three are live simultaneously, which
is why the v9-write / v11-read split above works. Also note the `version` string
now reads `P4 Code Review/...`; older builds reported `SWARM/...`, so don't match
on "SWARM" to detect the product.

## Webhooks / activity

P4 Code Review can fire webhooks on review/comment/state events (configured per
instance) -- useful for driving external bots/CI off review transitions. The
review's **terminal states** (approved/rejected/archived, and commit) are the
usual signals to act on.

## Quick URLs

- `https://<swarm-host>/<id>` -- jumps to a change or review by number.
- `https://<swarm-host>/reviews/<id>` -- canonical review page.
- `https://<swarm-host>/changes/<id>` -- a change.

## Common confusions

- `p4 review` (CLI) is **unrelated** -- it's an old counter/daemon command.
- The "review id" is its own changelist number, not the author's CL.
- "Swarm" in a hostname/URL is current and correct; the product name is
  P4 Code Review.
