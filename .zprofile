# This file is read on each login. Set things that you won't change very much in here. 
# But not PATH! 

eval "$(/opt/homebrew/bin/brew shellenv)"

if [ -f ~/.iterm2_shell_integration.zsh ]; then
	source ~/.iterm2_shell_integration.zsh
	export AUTOSWITCH_DEFAULT_PYTHON="/opt/homebrew/bin/python3"
fi


# Added by Toolbox App
export PATH="$PATH:/home/dj/.local/share/JetBrains/Toolbox/scripts"

