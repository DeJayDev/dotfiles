#!/bin/sh

echo "[.files] Setting App Specific Preferences..."

defaults write com.raycast.macos emojiPicker_skinTone medium
# check if these are redundant:
# defaults write com.raycast.macos raycastPreferredWindowMode compact
# defaults write com.raycast.macos raycastShouldFollowSystemAppearance -bool true
# defaults write com.raycast.macos raycastUI_preferredTextSize medium
# defaults write com.raycast.macos showFavoritseInCompactMode -bool false
