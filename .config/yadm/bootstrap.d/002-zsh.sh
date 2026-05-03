#!/bin/sh

if ! command -v zsh >/dev/null 2>&1; then
    if command -v apt >/dev/null 2>&1; then
        echo "[.files] Installing zsh via apt..."
        sudo apt update && sudo apt install -y zsh
    elif command -v pacman >/dev/null 2>&1; then
        echo "[.files] Installing zsh via pacman..."
        sudo pacman -S --noconfirm zsh
    fi
fi

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "[.files] Installing ohmyzsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --keep-zshrc
fi
