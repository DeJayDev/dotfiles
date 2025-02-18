#!/bin/sh

cd "$HOME"

echo "[.files] - Updating dotfiles to use ssh"
yadm remote set-url origin "git@github.com:dejaydev/dotfiles.git" 

echo "[.files] - Binding gitmodules file to yadm"
yadm gitconfig include.path ~/.gitmodules

echo "[.files] - Initializing submodules"
yadm submodule update --recursive --init
