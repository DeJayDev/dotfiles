#!/bin/sh
echo "[.files] - Installing Claude Code..."

# Native installer, drops the binary in ~/.local/bin (already on PATH) and self-updates.
curl -fsSL https://claude.ai/install.sh | bash
