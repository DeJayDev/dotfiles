#!/bin/zsh

brightness() {
  local level="$1"
  local display="${2:-1}"

  if [[ ! "$level" =~ ^[0-9]+$ ]] || (( level > 100 )); then
    echo "Please pass a brightness (0-100), optionally a display number" >&2
    return 1
  fi

  if [[ "$(uname)" == "Darwin" ]]; then
    ddcctl -d "$display" -b "$level"
    return
  fi

  ddcutil --display "$display" setvcp 10 "$level"
}
