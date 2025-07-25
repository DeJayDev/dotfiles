# This file is read on each login. Set things that you won't change very much in here. 
# But not PATH! 

# Homebrew
if [ -f /opt/homebrew/bin/brew ]; then
	eval "$(/opt/homebrew/bin/brew shellenv)"
	export HOMEBREW_AUTO_UPDATE_SECS=604800
fi

# iTerm
if [ -f ~/.iterm2_shell_integration.zsh ]; then
	source ~/.iterm2_shell_integration.zsh
	export AUTOSWITCH_DEFAULT_PYTHON="/opt/homebrew/bin/python3"
fi

# OrbStack: command-line tools and integration
if [ -f ~/.orbstack/shell/init.zsh ]; then
	source ~/.orbstack/shell/init.zsh 2>/dev/null || :
fi

export GOPATH=$HOME/.go
export QT_BEARER_POLL_TIMEOUT=-1
export AWS_PROFILE=dev-runpod
