#!/bin/sh
# Omarchy writes a launcher into ~/.local/bin for every coding agent it
# offers (install/user/mise.sh via omarchy-mise-install): a script that runs
# `mise use -g <tool>` on first use. This removes every such launcher except
# the agents named in the machine's opt-in, the way omarchy-remove-preinstalls
# decides what is Omarchy's: a regular file (not a symlink — Cursor's own
# installer links cursor-agent) carrying the `mise use -g` line; hermes is
# Omarchy's only when omarchy-install-hermes-cli says it owns it. Anything
# else at those paths is left alone. Omarchy re-provisioning writes them
# again, so the check catches a return.
# usage: omarchy-agent-launchers-prune.sh [check] <agent-to-keep>...
set -eu

MODE=install
if [ "${1:-}" = check ]; then MODE=check; shift; fi
BIN=$HOME/.local/bin

kept() {
  for keep in $KEEP; do [ "$keep" = "$1" ] && return 0; done
  return 1
}

omarchy_launcher() {
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  if [ "$(basename "$1")" = hermes ]; then
    omarchy-install-hermes-cli --owns >/dev/null 2>&1
  else
    grep -q '^mise use -g ' "$1"
  fi
}

extra() {
  for f in "$BIN"/*; do
    kept "$(basename "$f")" && continue
    omarchy_launcher "$f" && basename "$f"
  done
  return 0
}

KEEP="$*"
case "$MODE" in
check)
  [ -z "$(extra)" ]
  ;;
install)
  for name in $(extra); do
    rm -f "$BIN/$name"
    echo "removed $BIN/$name"
  done
  [ -z "$(extra)" ] || { echo "Omarchy launchers still present: $(extra | tr '\n' ' ')" >&2; exit 1; }
  ;;
esac
