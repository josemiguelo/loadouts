#!/bin/sh
# Shell completions for the user completions dir. Single source of truth:
# add a "name url" line to COMPLETIONS and both check and install follow.
# loadout runs `sh scripts/setup-completions.sh check` as the check and the
# default (install) mode on converge, fetching only what's missing.
set -eu

DIR="${ZDOTDIR:-$HOME}/completions"

# name (installed as _name)  |  source url
COMPLETIONS="
tmuxinator https://raw.githubusercontent.com/tmuxinator/tmuxinator/master/completion/tmuxinator.zsh
"

each() {
  echo "$COMPLETIONS" | while read -r name url; do
    [ -n "$name" ] || continue
    "$1" "$name" "$url" || exit 1
  done
}

check_one() { test -f "$DIR/_$1"; }
install_one() {
  if [ ! -f "$DIR/_$1" ]; then
    curl -fsSL "$2" -o "$DIR/_$1"
  fi
}

case "${1:-install}" in
  check)
    each check_one
    ;;
  install)
    mkdir -p "$DIR"
    each install_one
    ;;
  *)
    echo "usage: $0 [check|install]" >&2
    exit 2
    ;;
esac
