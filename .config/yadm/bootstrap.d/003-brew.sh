#!/bin/sh

if [[ "$(uname)" != "Darwin" ]]; then
  exit 0
fi

if ! [ -x "$(command -v brew)" ]; then
  echo '[.files] - Installing homebrew'
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | sh

  # Add brew to PATH for Apple Silicon
  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

echo '[.files] - Tapping non-default homebrew repos'
brew tap localsend/localsend
brew tap mdogan/zulu

echo '[.files] - Installing homebrew packages'
brew bundle --file=$HOME/.Brewfile