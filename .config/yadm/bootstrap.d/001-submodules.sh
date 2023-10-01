#!/bin/sh

cd "$HOME"

echo "[.files] - Binding gitmodules to this installation"
yadm gitconfig include.path ~/.gitmodules

echo "[.files] - Initializing submodules"
yadm submodule update --recursive --init
