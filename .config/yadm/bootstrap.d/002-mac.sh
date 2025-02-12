#!/bin/sh

if [[ "$(uname)" != "Darwin" ]]; then
  exit 0
fi

echo '[.files] - Setting Preferences'

# Smart Quotes and Dashes
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Smart Quotes in Messages
defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticQuoteSubstitutionEnabled" -bool false

#Enable Web Dev Tools in Safari (Useful!)
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.SafariContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

if [ -d "/Library/Developer/CommandLineTools" ]; then
  exit 0
fi

echo '[.files] - Installing XCode Command Line Tools'
xcode-select --install

