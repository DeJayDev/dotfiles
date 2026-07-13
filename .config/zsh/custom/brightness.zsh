#!/bin/zsh

brightness() {
  local level="$1"
  local display="$2"

  if [[ ! "$level" =~ ^[0-9]+$ ]] || (( level > 100 )); then
    echo "Please pass a brightness (0-100), optionally a display number" >&2
    return 1
  fi

  # ddcctl drives DDC over IOFramebuffer, which Apple Silicon doesn't expose. m1ddc is the arm64 path.
  if [[ "$(uname)" == "Darwin" ]]; then
    if [[ -n "$display" ]]; then
      m1ddc display "$display" set luminance "$level"
      return
    fi

    # No display given: hit every DDC-capable one. m1ddc lists a "(null)" device that can't be driven.
    m1ddc display list | grep -v '(null)' | sed -E 's/^\[([0-9]+)\].*/\1/' | while read -r d; do
      m1ddc display "$d" set luminance "$level"
    done
    return
  fi

  if [[ -n "$display" ]]; then
    ddcutil --display "$display" setvcp 10 "$level"
    return
  fi

  ddcutil setvcp 10 "$level"
}
