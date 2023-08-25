#!/bin/bash

set -e

#echo "Installing zsh..."
#sudo pacman --needed -S zsh

echo "Installing oh-my-zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

#echo "Installing required fonts..."
#sudo pacman --noconfirm -S ttf-iosevka-nerd
