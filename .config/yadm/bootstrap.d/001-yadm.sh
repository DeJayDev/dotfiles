#!/bin/sh

cd "$HOME"

if [ -f "$HOME/.ssh/id_ed25519" ] || [ -f "$HOME/.ssh/id_rsa" ]; then
  echo "[.files] - Updating dotfiles to use ssh"
  yadm remote set-url origin "git@github.com:dejaydev/dotfiles.git"
else
  echo "[.files] - WARNING: No SSH key found, skipping SSH remote switch"
  echo "[.files] - Run 'ssh-keygen -t ed25519' and add key to GitHub, then re-run this script"
fi

echo "[.files] - Binding gitmodules file to yadm"
yadm gitconfig include.path ~/.gitmodules

echo "[.files] - Initializing submodules"
yadm submodule update --recursive --init
