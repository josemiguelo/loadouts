#!/bin/sh
# Custom `loadout outdated` oracle for Omarchy shell plugins installed from
# git (~/.config/omarchy/plugins/<id>, a clone each): a row per plugin whose
# clone is behind its remote's HEAD, named by the plugin id. Silent when no
# plugin is installed.
#
# `update <id>` (loadout calls it per row) is Omarchy's own `omarchy plugin
# update <id> --yes`: it fast-forwards, validates (rolling back a failure)
# and reloads the shell's plugins.
set -eu

PLUGINS=$HOME/.config/omarchy/plugins
GCB="$(dirname "$0")/git-clones-behind.sh"
# The folder is named by the plugin id.
export GCB_NAME='basename "$dir"'

if [ "${1:-}" = "update" ]; then
  id=${2:?usage: omarchy-plugins.sh update <id>}
  [ -d "$PLUGINS/$id/.git" ] || { echo "no git-managed plugin '$id'" >&2; exit 1; }
  exec omarchy plugin update "$id" --yes
fi

dirs=""
for dir in "$PLUGINS"/*/; do
  [ -d "$dir.git" ] && dirs="$dirs ${dir%/}"
done
# shellcheck disable=SC2086
[ -z "$dirs" ] || exec sh "$GCB" $dirs
