#!/bin/zsh

brightness() {
  readonly brightness="${1:?"Please pass a brightness (0-100)"}"

  if [ $brightness -lt 0 ] || [ $brightness -gt 100 ]; then
    echo "Please pass a brightness (0-100)" >&2; exit 42069
  fi

  ddcutil setvcp 10 $brightness
}  
