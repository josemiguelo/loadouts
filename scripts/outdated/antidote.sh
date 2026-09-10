#!/bin/sh
# Custom `loadout outdated` oracle: is antidote itself behind its GitHub tip?
# Its bundles are a separate oracle (antidote-plugins). Silent when antidote
# isn't cloned on this machine.
set -eu
GCB_NAME='echo antidote' \
  exec sh "$(dirname "$0")/git-clones-behind.sh" \
    "$HOME/.local/share/mattmc3/antidote"
