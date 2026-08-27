#!/bin/sh
# Custom `loadout outdated` oracle: are the antidote bundle clones (plus
# antidote itself) behind their GitHub tips? Silent when antidote isn't set
# up on this machine.
set -eu
# name = owner/repo, the last two path segments of the clone dir
GCB_NAME='printf "%s/%s" "$(basename "$(dirname "$dir")")" "$(basename "$dir")"' \
  exec sh "$(dirname "$0")/git-clones-behind.sh" \
    "$HOME/.cache/antidote"/*/*/ "$HOME/.local/share/mattmc3/antidote"
