#!/bin/sh
# Removes the named Omarchy web apps (launcher + icon) with Omarchy's own
# omarchy-webapp-remove. Omarchy copies its bundled web apps back whenever it
# re-provisions applications (omarchy-refresh-applications: a re-provision,
# restoring preinstalls, some migrations), so the check catches a return.
# Names are the launchers' file names (HEY for HEY.desktop); loadout splits
# arguments on spaces, so a name with one can't be passed.
# usage: omarchy-webapps-remove.sh [check] <name>...
set -eu

MODE=install
if [ "${1:-}" = check ]; then MODE=check; shift; fi
[ $# -gt 0 ] || { echo "usage: $0 [check] <name>..." >&2; exit 2; }

DIR=$HOME/.local/share/applications

still_there() {
  for name in "$@"; do
    [ -f "$DIR/$name.desktop" ] && echo "$name"
  done
  return 0
}

case "$MODE" in
check)
  [ -z "$(still_there "$@")" ]
  ;;
install)
  for name in $(still_there "$@"); do
    OMARCHY_REMOVE_NOTIFY=false omarchy-webapp-remove "$name"
  done
  left=$(still_there "$@")
  [ -z "$left" ] || { echo "still installed after removal: $left" >&2; exit 1; }
  ;;
esac
