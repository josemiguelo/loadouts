#!/bin/sh
# Custom `loadout outdated` oracle: are the antidote bundle clones behind
# their GitHub tips? antidote itself is a separate oracle. Silent when
# antidote isn't set up on this machine.
set -eu
# name = owner/repo, the last two path segments of the clone dir
GCB_NAME='printf "%s/%s" "$(basename "$(dirname "$dir")")" "$(basename "$dir")"' \
  exec sh "$(dirname "$0")/git-clones-behind.sh" "$@" \
    "$HOME/.cache/antidote"/*/*/
