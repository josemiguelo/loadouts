#!/bin/sh
# Hyprland settings kept in this repo: hypr-config/<file>.lua (next to this
# script) holds plain hl.config and hl.animation calls for
# ~/.config/hypr/<file>.lua, the matching personal-overrides file
# Omarchy's hyprland.lua loads after its defaults (input, looknfeel,
# bindings, …). The machine's opt-in names the files
# ("omarchy-hypr-config input looknfeel"). Install writes each file's
# contents into a block between markers in the Hyprland file, rewritten in
# place on every install. The check doesn't read text: hypr-option.lua
# evaluates the repo file alone to list the settings it makes, then the whole
# Hyprland config, and every one of those settings must end up with that
# value — a later override anywhere in the chain fails it. Install then
# reloads the running Hyprland and requires no config errors.
# usage: omarchy-hypr-config.sh [check] <file>...
set -eu

MODE=install
if [ "${1:-}" = check ]; then MODE=check; shift; fi
[ $# -gt 0 ] || { echo "usage: $0 [check] <file>..." >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
SETTINGS=$HERE/hypr-config
PROBE=$HERE/hypr-option.lua
. "$HERE/hypr-live.sh"

# Settings the named repo files make, as <path>\t<value> lines.
wanted() {
  for name in "$@"; do
    src=$SETTINGS/$name.lua
    [ -f "$src" ] || { echo "no $src" >&2; return 1; }
    lua "$PROBE" leaves "$src" || return 1
  done
}

# Wanted settings the whole Hyprland config doesn't end up with.
missing() {
  want=$(wanted "$@") || return 1
  have=$(lua "$PROBE" leaves) || return 1
  printf '%s\n' "$want" | grep -vxF -e "$(printf '%s\n' "$have")" || true
}

case "$MODE" in
check)
  out=$(missing "$@") || exit 1
  [ -z "$out" ]
  ;;
install)
  wanted "$@" >/dev/null || exit 1
  for name in "$@"; do
    conf=$HOME/.config/hypr/$name.lua
    begin="-- >>> Managed by loadout (omarchy-hypr-config: hypr-config/$name.lua)"
    end="-- <<< Managed by loadout (omarchy-hypr-config: hypr-config/$name.lua)"
    mkdir -p "$(dirname "$conf")"
    touch "$conf"
    rest=$(awk -v b="$begin" -v e="$end" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' "$conf")
    { printf '%s\n\n' "$rest"; echo "$begin"; cat "$SETTINGS/$name.lua"; echo "$end"; } > "$conf"
  done
  out=$(missing "$@") || exit 1
  [ -z "$out" ] || {
    printf 'not in effect after install (is the file loaded? overridden later?):\n%s\n' "$out" >&2
    exit 1
  }
  sig=$(live_instance)
  if [ -n "$sig" ]; then
    HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl -q reload
    errors=$(HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl configerrors | grep -v '^[[:space:]]*$' || true)
    [ -z "$errors" ] || { echo "Hyprland reports config errors after the reload: $errors" >&2; exit 1; }
  else
    echo "Hyprland isn't reachable from here; applies at the next login."
  fi
  ;;
esac
