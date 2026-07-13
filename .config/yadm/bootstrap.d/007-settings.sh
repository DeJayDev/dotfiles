#!/bin/sh

echo "[.files] Setting App Specific Preferences..."

if [ "$(uname)" != "Darwin" ]; then
  exit 0
fi

defaults write com.raycast.macos emojiPicker_skinTone medium

# iTerm2: install dynamic profile (font + ligatures + left option key as Esc+)
ITERM_PROFILES_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
mkdir -p "$ITERM_PROFILES_DIR"
ln -sf "$HOME/.config/iterm2/DynamicProfiles/dotfiles.json" "$ITERM_PROFILES_DIR/dotfiles.json"

# iTerm2: Appearance > Dimming > "Dim inactive split panes"
defaults write com.googlecode.iterm2 DimInactiveSplitPanes -bool false

# check if these are redundant:
# defaults write com.raycast.macos raycastPreferredWindowMode compact
# defaults write com.raycast.macos raycastShouldFollowSystemAppearance -bool true
# defaults write com.raycast.macos raycastUI_preferredTextSize medium
# defaults write com.raycast.macos showFavoritseInCompactMode -bool false
