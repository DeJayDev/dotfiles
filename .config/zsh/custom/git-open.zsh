#!/usr/bin/env bash

# thank you ben :)
# https://github.com/Benricheson101/dots/blob/f87cfd8c2932bb16ea90cab71da4b5ceff815f47/scripts/git-open#L3

function git-open() {
  local remote="${1:-origin}"
  local remote_url
  remote_url="$(git remote get-url "$remote")"

  if [ -z "$remote_url" ]; then
    return 1
  fi

  local url
  url="$(sed -E 's,((git|ssh|https?):\/\/|git@)([[:alnum:]\._-]+):?([[:alnum:]\.@\:\/~_-]+)(\.git),https://\3/\4,g' <<< "$remote_url")"

  if [ "$(uname)" != "Darwin" ]; then
    xdg-open "$url"
    return
  fi

  open "$url"
}
