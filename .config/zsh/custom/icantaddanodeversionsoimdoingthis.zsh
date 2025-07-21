# I was told I can't add a node-version to a repo at work but the repo has a hard dep on Node 18 so I have actually no choice but to do this which is terrible.
# Written by GPT 4o

autoload -Uz add-zsh-hook

# Track previous dir to detect entry/exit
_fnm_prev_dir=""

function _fnm_auto_switch() {
  local target_dir="/Users/dj/runpod/runpod"

  # Entering the target directory
  if [[ "$PWD" == "$target_dir" && "$_fnm_prev_dir" != "$target_dir" ]]; then
    fnm use 18
  fi

  # Leaving the target directory
  if [[ "$PWD" != "$target_dir" && "$_fnm_prev_dir" == "$target_dir" ]]; then
    fnm use system
  fi

  _fnm_prev_dir="$PWD"
}

add-zsh-hook chpwd _fnm_auto_switch

