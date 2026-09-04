#!/usr/bin/env bash
# Invoke Fable via Claude Code CLI. Prompt from -f file or stdin.
set -euo pipefail

cwd=""
prompt_file=""
read_only=""

usage() {
  echo "Usage: ask-fable.sh [-C dir] [-f promptfile] [-r]" >&2
  echo "  Prompt from -f or stdin. Pins: --model fable --effort high --dangerously-skip-permissions -p" >&2
  echo "  -r  read-only: restrict Fable to Read/Glob/Grep/WebFetch/WebSearch (no Bash, no edits)" >&2
  exit 2
}

while getopts "C:f:rh" opt; do
  case "$opt" in
    C) cwd=$OPTARG ;;
    f) prompt_file=$OPTARG ;;
    r) read_only=1 ;;
    h) usage ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

if [[ $# -gt 0 ]]; then
  echo "ask-fable.sh: unexpected arguments: $*" >&2
  usage
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "ask-fable.sh: claude not found on PATH" >&2
  exit 1
fi

tmp=""
cleanup() {
  if [[ -n "$tmp" && -f "$tmp" ]]; then
    rm -f "$tmp"
  fi
}
trap cleanup EXIT

if [[ -n "$prompt_file" ]]; then
  if [[ ! -f "$prompt_file" ]]; then
    echo "ask-fable.sh: prompt file not found: $prompt_file" >&2
    exit 1
  fi
  # Absolutize before any -C cd so relative -f still works
  prompt_path=$(readlink -f "$prompt_file")
else
  if [[ -t 0 ]]; then
    echo "ask-fable.sh: no -f and stdin is a TTY; pass -f or pipe a prompt" >&2
    exit 1
  fi
  tmp=$(mktemp)
  cat >"$tmp"
  prompt_path=$tmp
fi

if [[ ! -s "$prompt_path" ]]; then
  echo "ask-fable.sh: empty prompt" >&2
  exit 1
fi

# Fable is a fresh one-shot subprocess: it cannot see the caller's conversation,
# so prompts that reference it are broken by construction. High-precision phrases only.
referents='as (mentioned|discussed|noted) (above|earlier)|see above|as we discussed|we (just |already )?(discussed|talked about|looked at)|continue where you left off|per (our|this) conversation|in (this|our) (conversation|thread|session)|the (file|code|error|function) (above|we were)'
if match=$(grep -inE "$referents" "$prompt_path" | head -3); then
  echo "ask-fable.sh: prompt references a conversation Fable cannot see:" >&2
  echo "$match" >&2
  echo "Fable is a one-shot subprocess with no shared context. Rewrite the prompt to be self-contained: inline the facts these phrases point at." >&2
  exit 1
fi

run_claude() {
  local tools="default"
  if [[ -n "$read_only" ]]; then
    tools="Read,Glob,Grep,WebFetch,WebSearch"
  fi
  # stdin form avoids ARG_MAX on large prompts; -p with redirected stdin works
  claude \
    --model fable \
    --effort high \
    --dangerously-skip-permissions \
    --tools "$tools" \
    -p <"$prompt_path"
}

if [[ -n "$cwd" ]]; then
  if [[ ! -d "$cwd" ]]; then
    echo "ask-fable.sh: -C directory not found: $cwd" >&2
    exit 1
  fi
  (cd "$cwd" && run_claude)
else
  run_claude
fi
