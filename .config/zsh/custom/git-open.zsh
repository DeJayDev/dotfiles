# thank you ben :)
# https://github.com/Benricheson101/dots/blob/f87cfd8c2932bb16ea90cab71da4b5ceff815f47/scripts/git-open#L3

function git-open() {
  remote="${1:-origin}"
  remote_url="$(git remote get-url $remote)"

  if [ -z $remote_url ]; then
    exit 1
  fi

  url="$(sed -E 's,((git|ssh|https?):\/\/|git@)([[:alnum:]\._-]+):?([[:alnum:]\.@\:\/~_-]+)(\.git),https://\3/\4,g' <<< "$remote_url")"

  open "$url"
}
