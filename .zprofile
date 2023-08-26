# This file is read on each login. Set things that you won't change very much in here. 
# But not PATH! 

eval "$(/opt/homebrew/bin/brew shellenv)"

if [ -f ~/.iterm2_shell_integration.zsh ]; then
	source ~/.iterm2_shell_integration.zsh
fi
