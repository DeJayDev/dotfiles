#!/bin/sh

set -e

yadm gitconfig -f .gitmodules --get-regexp '^submodule\..*\.path$' |
    while read path_key local_path
    do
        url_key=$(echo $path_key | sed 's/\.path/.url/')
        url=$(yadm gitconfig -f .gitmodules --get "$url_key")
        yadm submodule add $url $local_path || true
    done
