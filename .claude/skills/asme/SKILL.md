---
name: asme
description: "Rewrite outward-facing prose into the user's voice, for a reader who wasn't in the session: PR bodies, commit messages, reviewer replies, customer and support replies, status updates, READMEs, docs, CLAUDE.md and agent docs, specs, tasks handed to someone else, postmortems, emails. Word budgets, plain changelog bullets, checked facts, no session shorthand, no LLM filler. Use when the user asks to tighten, shorten, or rewrite text, before you draft any of those for them, and again on every later round of edits to that text."
argument-hint: "[what to tighten: pasted text, a file path, or 'the PR body']"
---

# asme

Target, as the user typed it: **$ARGUMENTS**

Resolve it: pasted text is the draft; a path gets read; "the PR body" or a PR
number means `gh pr view --json title,body`; "my comment" or "the reply" is
the most recent draft in this conversation. If it is genuinely unclear which
artifact or who reads it, ask in one line and stop.

Before drafting, read the user's own recent artifacts of the same kind and
match them over anything below:

- PR body: `gh pr list --author @me --state merged --limit 5 --json body`.
- Commit message or branch name: `git log --author="$(git config user.email)" -10 --format=%s`.
  Conventional commits when that is what's there.
- Reply in a thread: the whole thread, including the user's earlier messages in it.
- Status page or any post in a series: the earlier posts. They set the length
  and the detail.

Then check the facts. Every claim in the draft, whether yours or the user's,
must trace to something this session actually verified: code, logs, a query,
docs. A claim nobody verified gets verified now, cut, or named in the
trailing line. Never state a cause, a status, a fix time, or a deploy as fact
when it was inferred. Never add a commitment the user didn't make ("we're
fixing it", "goes out tonight"). If the user's draft claims something you
can't back ("almost entirely removed"), measure it or say so; don't soften
the wording to dodge it.

Cover the whole change. Every change in the diff gets a line, and unrelated
ones go in an `Also,` list; never hand them back to the user to split out.

Then reread it as someone who only has this text. Anything they couldn't
follow gets explained or goes; anything they don't need goes.

Output the artifact only, in a fenced block when it will be pasted
somewhere, then at most one line naming what was cut or what is unverified.
No investigation summary before it, no "what changed" list after it, no
"here's a tighter version". Show it. If the user's request already named
the action ("push and open a PR", "post it", "update the PR body", "commit
this"), that is the go-ahead: do exactly that action after drafting, without
asking again. Otherwise `gh pr create`, `gh pr edit`, `git commit`, sending,
or writing the text to a file waits for the user's go-ahead. When two lengths
are plausible, give the shorter one, unless the user asked for more story or
detail.

## The voice

These are observed, not invented: session corrections plus 134 PR bodies
the user wrote by hand.

- **Length is a number.** PR body: median 70 words, one to three short
  paragraphs. Reply to a reviewer: four sentences. Fix PR: one sentence.
  Customer reply: two to four sentences. Status page update: one sentence.
  Macro or canned reply: one or two. Anything else: "three max". Bullet
  lists: four items, never five or more.
- **Open with the failure or the change, one declarative sentence.** "X
  would fail whenever…", "Adds an opt-in mode where…", "Root cause: …".
  Never "This PR does the following".
- **Formatting is plain.** No bold, no tables. Headings only when the user's
  recent bodies use them; `Summary`, `Test plan`, `Checklist`, `Type of
  change`, `Why it won't break…` only ever come from templates or LLMs.
  A multi-change PR is a failure-first paragraph, then `Now,` and `Also,`
  lists of plain bullets.
- **A bullet is one changelog line**, not a mechanism paragraph: "Read
  queries no longer wait on the write limiter; writes still do." The user
  calls the other kind "a newspaper article".
- **Link the evidence, cut the story.** A commit URL, PR number, or run link
  sits next to the explanation as proof. What gets cut is the story of how
  you found it. In a template or macro, use its own variables, never a
  hardcoded URL.
- **Deliberate omission is a tool, not a gap.** If the user cut a fact, a
  sentence, a link, an issue number, or a technical detail between rounds, it
  stays gone. Don't re-add it, and don't suggest re-adding it, even with
  "if you cut it on purpose, ignore this".
- **Measurements are before → after with a unit,** inline, and the multiplier
  when it is big: `4.2s → 200ms (~21x)`. No "approximately", "up to",
  "roughly". Each one says what was measured and why it matters; a bare label
  and a number is not a measurement.
- **Old to new pivots on "instead of".** "We don't actually need all of that,
  so…" is the move for justifying a cut.
- **Caveats are owned residuals, not disclaimers.** Close on the operational
  consequence or the one real thing left: "No new database indexes." "This
  may harm the live feel, but it's easily undoable." Never a guard sentence
  or "validated against real X, not just reasoned about"; the user calls
  that prose "kinda mid".
- **Verification, when it earns a line, is a bare statement of what ran.**
  "Ran the same build command CI runs." Never a checklist, a testing
  paragraph, or how you got the numbers.
- **Strip on sight:** provably, properly, the honest tradeoff, copy-ready,
  robust, comprehensive, praise of the work, and hedges ("might", "should
  probably", "I think", "there's a small chance") unless they name a real
  uncertainty the user owns. Strip trailing justification clauses ("That
  lets me find the exact job", "so you can skip that step"). Parenthetical
  asides that add a fact stay; the user writes them. A parenthetical that
  softens the claim just made goes.
- **Profanity lives in chat, never in the artifact.** An interjection or
  emoji ("yep!") is fine in a personal or low-stakes PR and absent from
  on-call and infra writeups. Deadlines and asks are concrete: "a call on
  the books before end of day Wednesday".
- **Docs, CLAUDE.md, specs, config comments, and values files must look like
  they were there the whole time**, not bolted on by an LLM. They say what is
  true now, for whoever opens them next. Match the surrounding voice.
  Comments are one line.

## Customer and support replies

- Answer the question they asked, in the first sentence. If you can't answer
  yet, ask for the one thing you need and nothing else.
- Give them the outcome, not the timeline of how it happened.
- Warm and plain, never cold or teaching. One apology when something actually
  broke ("Sorry about this one!"); never a ritual one ("Sorry for the delay",
  "I believe this has been fixed").
- Offers are honest and conditional: "If this is blocking you, let me know."
- Security and disclosure replies are cool and factual: what is intended,
  why it isn't a vulnerability, the bounty policy. Don't explain the protocol
  to the reporter.
- If you don't understand the customer's setup well enough to answer,
  research it before drafting until you can answer their actual question. A
  confident wrong reply costs more rounds than the research.

## When the draft is the user's own

Edit surgically. Keep the user's sentences verbatim wherever they already
hold; fix only the robotic opener, the overlong bullet, the hedge, and any
fact that is wrong, which you name in the trailing line. Don't add
mechanisms, details, links, or sentences of your own, and don't swap their
words for synonyms ("initialize" → "start"). Do not restructure their bullets
into yours. Then say what you touched in one line ("four edits; everything
else is verbatim you").
