---
name: tighten
description: Rewrite a PR body, reviewer reply, README, postmortem, or email into dj's voice. Short, bold-lead bullets, links over stories.
disable-model-invocation: true
argument-hint: "[what to tighten: pasted text, a file path, or 'the PR body']"
---

# Tighten

Target, as the user typed it: **$ARGUMENTS**

Resolve it: pasted text is the draft; a path gets read; "the PR body" or a PR
number means `gh pr view --json title,body`; "my comment" or "the reply" is
the most recent draft in this conversation. If it is genuinely unclear which
artifact or who reads it, ask in one line and stop.

Output the tightened artifact only, in a fenced block when it will be pasted
somewhere, then at most one line naming what was cut. No preamble, no
"here's a tighter version". When two lengths are plausible, give the shorter
one; the user will ask for more.

## The voice

These are observed, not invented: session corrections plus 134 PR bodies
the user wrote by hand.

- **Length is a number.** PR body: median 70 words, one to three short
  paragraphs. Reply to a reviewer: four sentences. Fix PR: one sentence.
  Anything else: "three max". Bullet lists: four items, never five or more.
- **Open with the failure or the change, one declarative sentence.**
  "Reviews would fail and get stuck in requeue loops whenever…", "Adds an
  opt-in mode (`GREPBOX_BARE_CACHE_VOLUME`) where…", "Root cause: …". Never
  "This PR does the following".
- **Headings are rare** (one body in six). A multi-part change gets two to
  four short ones from the user's own set: `Changes`, `Scope`, `How`, `Why`,
  `Root cause`, `Notes`, `# tests done`. `Summary`, `Test plan`, `Checklist`,
  `Type of change`, `Why it won't break…` only ever come from templates or
  LLMs; delete them.
- **Bullets are a bold-lead sentence, then one or two plain sentences of
  mechanism.** No sub-bullets beyond a single nested pair. No trailing "why
  this matters".
- **Link the evidence, cut the story.** A commit URL, `#NNNN`, or a run link
  sits next to the explanation as proof; it does not replace the mechanism.
  What gets cut is the story of how you found it. Nobody reads the story.
- **Deliberate omission is a tool, not a gap.** If the user cut a fact or said
  "don't mention X", it stays gone. Never re-add a true fact because it seems
  important; ask if you think it is load-bearing.
- **Measurements are before → after with a unit,** and the multiplier when
  it is big: `4177ms → ~200ms (~21x)`, `283MB and 77,000 commits` versus
  `14MB and ~6 seconds`, `376 reviews failed`. Several rows means a
  Before/After table. No "approximately", "up to", "roughly".
- **Old to new pivots on "instead of".** "We don't actually need all of that,
  so…" is the move for justifying a cut.
- **Caveats are owned residuals, not disclaimers.** Close on the operational
  consequence or the one real thing left: "No new database indexes." "At this
  time, `SWARM_POLLING_ENABLED` will need to be turned on for NVIDIA." "This
  may harm the live feel, but it's easily undoable." Never a guard sentence
  or "validated against real X, not just reasoned about"; the user calls
  that prose "kinda mid".
- **Verification is a bare statement of what ran and what it showed.**
  "full worker suite green (460 environment + 4476 agent tests)". Never a
  checklist.
- **Strip on sight:** provably, properly, the honest tradeoff, copy-ready,
  robust, comprehensive, praise of the work, and hedges ("might", "should
  probably", "I think") unless they name a real uncertainty the user owns.
  Parenthetical asides that add a fact stay; the user writes them. A
  parenthetical that softens the claim just made goes.
- **Audience floor: three infra engineers.** No jargon that needs a glossary.
  "Use simpler words" means the reader should not have to ask what a phrase
  means. Direct second person to the reader is fine ("Existing customers,
  that's in docs/operations.md").
- **Profanity lives in chat, never in the artifact.** An interjection or
  emoji ("yep!", the lizard) is fine in a personal or low-stakes PR and absent
  from on-call and infra writeups. Deadlines and asks are concrete: "a call on
  the books before end of day Wednesday".
- **Docs, config comments, and values files must look like they were there
  the whole time**, not bolted on by an LLM. Match the surrounding voice.
  Comments are one line: `# override when hydra cannot reach auth-v2 in-cluster`.

## When the draft is the user's own

Edit surgically. Keep the user's sentences verbatim wherever they already
hold; fix only the robotic opener, the overlong bullet, the hedge. Then say
what you touched in one line ("four edits; everything else is verbatim you").
Do not restructure their bullets into yours.

## Accepted shapes

Fix PR, one sentence, written by the user:

```
On-prem `greptile login` failed with `invalid_grant` because the CLI sent a
`127.0.0.1` loopback redirect that never matched the `localhost` the auth code
is bound to, so the CLI now sends `localhost` (hydra also registers the
`127.0.0.1` callbacks).
```

Feature PR, prose, written by the user:

```
the reply agent is powered by the platform mcp servers, but they all have
varying pitfalls and arent a great long term solution.

I've created a new greptile-platform MCP server that exposes at the very least
a get_diff tool so every platform has a unified method of doing this. Our
ISCMClient has this written out uniquely for every platform already. Long
term, this is a gateway to removing our dependency on the third party MCP
servers in the first place.
```

Multi-change PR, list form, written by the user:

```
Adds support for auth-v2 and fixes a bug with how we render out Azure Foundry settings.

Also:
* Uses the same PLATFORM_API_KEY and PLATFORM_BASE_URL format
* Ships and enables "auth v2". Existing customers, that's in docs/operations.md
* Bundles and enables Redis.
* Writes some documentation.
```

Reply to a reviewer, accepted as written:

```
Real mechanism, but pre-existing and not P4-specific: the all-or-nothing
`hasSectionConfigs` gate is the established semantic — any section-format key
means legacy flags are dead. GitHub/GitLab drop the legacy flag in mixed
configs identically (just masked by their default-on), and the same gate
exists independently in `packages/settings`. Perforce was unconditionally off
before this commit, so the mixed case isn't a regression. Fixing it only for
P4 would diverge from other platforms; the real fix is per-flag conversion in
`convertLegacySectionFlags`, which changes all platforms and belongs in its
own change.
```
