#!/bin/sh
# Custom `loadout outdated` oracle: is antidote itself behind its GitHub tip?
# Its bundles are a separate oracle (antidote-plugins). Silent when antidote
# isn't cloned on this machine.
set -eu
# Same expression the installer clones into (scripts/maintain/zsh-plugins.sh):
# with XDG_DATA_HOME set, a hardcoded ~/.local/share looked where antidote
# was never installed, and this oracle goes silent rather than saying so.
GCB_NAME='echo antidote' \
  exec sh "$(dirname "$0")/git-clones-behind.sh" "$@" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/mattmc3/antidote"
