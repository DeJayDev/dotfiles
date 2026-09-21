#!/bin/sh
echo "[.files] - Installing Claude Code..."

# Native installer, drops the binary in ~/.local/bin (already on PATH) and self-updates.
curl -fsSL https://claude.ai/install.sh | bash

# Point the agent skills dir at Claude's yadm-tracked skills so both stay in sync.
mkdir -p "$HOME/.agents"
ln -sfn "$HOME/.claude/skills" "$HOME/.agents/skills"
