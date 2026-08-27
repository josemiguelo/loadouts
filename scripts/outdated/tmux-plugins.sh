#!/bin/sh
# Custom `loadout outdated` oracle: are the tmux plugin clones (tpack dirs,
# named <plugin>-<hash>) behind their GitHub tips? Silent when tmux plugins
# aren't set up on this machine.
set -eu
# name = dir basename minus tpack's trailing hash suffix
GCB_NAME='basename "$dir" | sed "s/-[0-9a-f]\{12\}$//"' \
  exec sh "$(dirname "$0")/git-clones-behind.sh" "$HOME/.config/tmux/plugins"/*/
