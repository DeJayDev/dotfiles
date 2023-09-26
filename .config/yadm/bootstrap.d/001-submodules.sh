#!/bin/sh

cd "$HOME"

echo "[.files] - Binding gitmodules to this installation"
yadm gitconfig --global include.path ~/.

echo "[.files] - Initializing submodules"
yadm submodule update --recursive --init
