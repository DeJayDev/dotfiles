---
name: ask-fable
description: >
  Consult Fable 5 (Claude Code CLI) for hard questions, second opinions, stuck
  situations, and optional implementation. Use when the user says /ask-fable,
  "ask Fable", "consult Fable", "second opinion from Fable", or when a hard
  judgment call or failed approaches warrant escalating to Fable.
compatibility: Requires `claude` CLI on PATH with Fable model access
---

# Ask Fable

Shell out to a fresh Fable 5 session via Claude Code CLI. Works from any host.
Write whatever prompt you need — Fable starts cold and has tools.

## When

- Hard / non-trivial questions, stuck after failures, second opinions
- Explicit user request for Fable
- Not for trivial lookups the host can answer alone

## Self-call guard

If the host is already Fable 5: answer in-process unless the user explicitly
wants a fresh/isolated Fable session (`--force`, "fresh Fable", etc.).

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

Raw CLI if the helper is missing:

```bash
(cd <repo> && claude --model fable --effort high --dangerously-skip-permissions -p <"$P")
```

- Foreground only; fresh call every time (no resume)
- If Fable implemented something: check `git status` and the full diff before treating it as done
