#!/bin/sh

if [ -n "$ZSH" ]; then
    exit 0
fi

echo "[.files] Installing ohmyzsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --keep-zshrc

# TODO: iTerm Config, what do I want to set?