# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
export PATH=$PATH:$HOME/bin:$HOME/.cargo/bin:$GOPATH/bin:$HOME/.local/bin:/usr/local/bin

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Would you like to use another custom folder than $ZSH/custom?
ZSH_CUSTOM=~/.config/zsh/custom

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  autoswitch_virtualenv
  dotenv
  extract 
  git 
  gradle-completion
  poetry 
  zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

# User configuration

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Add custom completions
fpath=($ZSH_CUSTOM/completions $fpath)

# lol
export CHROME_EXECUTABLE=/usr/bin/microsoft-edge-dev

# fnm
export PATH=$PATH:$HOME/.local/share/fnm
eval "$(fnm env --use-on-cd --resolve-engines --corepack-enabled)"

# Add custom completions
fpath=($ZSH_CUSTOM/completions $fpath)

# zoxide
eval "$(zoxide init zsh)"

# bun completions
[ -s "/Users/dj/.bun/_bun" ] && source "/Users/dj/.bun/_bun"

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"
