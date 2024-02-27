# This file is read on each login. Set things that you won't change very much in here. 
# But not PATH! 

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# iTerm
if [ -f ~/.iterm2_shell_integration.zsh ]; then
	source ~/.iterm2_shell_integration.zsh
	export AUTOSWITCH_DEFAULT_PYTHON="/opt/homebrew/bin/python3"
fi

# JetBrains Toolbox, comment courtesy of JetBrains.
# Added by Toolbox App
export PATH="$PATH:/home/dj/.local/share/JetBrains/Toolbox/scripts"

# thefuck
eval "$(thefuck --alias)"
