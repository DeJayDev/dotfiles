---
name: ask-fable
description: >
  Consult Fable (Claude Code CLI) for hard questions, second opinions, stuck
  situations, and optional implementation. Stateless one-shot: each call spawns
  a fresh subprocess that sees only the prompt text -- never this conversation,
  never prior calls. No follow-ups exist. Use when the user says /ask-fable,
  "ask Fable", "consult Fable", "second opinion from Fable", or when a hard
  judgment call or failed approaches warrant escalating to Fable.
compatibility: Requires `claude` CLI on PATH with Fable model access
---

# Ask Fable

Each call is ONE SHOT. Fable is a fresh subprocess that receives exactly one
input: your prompt file. It cannot see this conversation, your context, or any
previous /ask-fable call, and there is no session to reply to -- a second call
is a stranger starting from zero. If a fact isn't in the prompt, Fable doesn't
know it.

## When

- Hard / non-trivial questions, stuck after failures, second opinions
- Explicit user request for Fable
- Not for trivial lookups the host can answer alone

## Compose the prompt

Write it as a briefing for someone with no shared history. One prompt carries
everything:

1. The exact question and what shape of answer you want (diagnosis, patch,
   review verdict, design pick)
2. All context: repo/file paths, error text verbatim, constraints, environment
3. What was already tried and how each attempt failed

Conversation referents ("as discussed", "the file above", "continue where you
left off") point at nothing Fable can see. The helper script rejects prompts
containing them -- fix the prompt, don't work around the check.

To iterate on an insufficient answer: there is no reply. Compose a new
self-contained prompt that quotes Fable's previous answer verbatim and states
what was wrong or missing.

## Invoke

Helper next to this skill pins model/effort/permissions. Resolve the skill dir
from wherever you loaded this file, then:

```bash
SKILL_DIR=<dir containing this SKILL.md>
P=$(mktemp)
cat >"$P" <<'EOF'
<your prompt>
EOF
"$SKILL_DIR/scripts/ask-fable.sh" -C <repo> -f "$P"
rm -f "$P"
```

stdin works too. Prefer a temp file over fragile quoting for long prompts.

Add `-r` for a read-only Fable (analysis, review, second opinion): tools are
limited to Read/Glob/Grep/WebFetch/WebSearch -- no Bash, no edits, nothing to
check afterward. Omit `-r` when you want Fable to implement.

Raw CLI if the helper is missing (no referent check on this path -- you are
the check):

```bash
(cd <repo> && claude --model fable --effort high --dangerously-skip-permissions -p <"$P")
```

- Foreground only
- If Fable implemented something: check `git status` and the full diff before
  treating it as done
