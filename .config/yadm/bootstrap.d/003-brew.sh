#!/bin/sh

if [[ "$(uname)" != "Darwin" ]] || [ -x "$(command -v brew)" ]; then
  exit 0
fi

echo '[.files] - Installing homebrew'
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | sh

echo '[.files] - Installing homebrew packages'
brew bundle --file=$HOME/.Brewfile