#!/bin/sh
# Custom `loadout outdated` oracle: are the lazy.nvim plugin clones behind
# their GitHub tips? lazy.nvim checks each clone out at its lazy-lock.json
# pin, so clone HEAD = the committed pin and the shared engine's HEAD-vs-tip
# comparison is exactly pin-vs-upstream. Silent when neovim/lazy isn't set
# up on this machine.
set -eu
GCB_NAME='basename "$dir"' \
  exec sh "$(dirname "$0")/git-clones-behind.sh" "$HOME/.local/share/nvim/lazy"/*/
