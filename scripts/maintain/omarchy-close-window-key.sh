#!/bin/sh
# SUPER+Q closes the window, and whatever key Omarchy uses for that stops
# doing it. Omarchy's key isn't assumed (SUPER+W today, in default/hypr/
# bindings/tiling.lua): hypr-option.lua evaluates Omarchy's defaults alone
# (hypr-omarchy-defaults.lua) and lists the keys bound to the close action.
# The block in ~/.config/hypr/bindings.lua, Omarchy's personal-bindings
# file, unbinds those keys and binds SUPER+Q — hl.unbind first, as Omarchy's
# comments say (two binds on one key would both fire). Install rewrites the
# block between its markers, so it follows Omarchy if it moves the action.
# Those keys are only unbound, never given anything else. The check
# evaluates the whole config, not the file's text; install confirms it in
# the running Hyprland when there is one — by description, since with a Lua
# config hyprctl binds shows a function reference, never the action.
# Modes: `check` / `install` (default).
set -eu

KEY="SUPER + Q"
ACTION="<window.close>"
CONF=$HOME/.config/hypr/bindings.lua
HERE="$(cd "$(dirname "$0")" && pwd)"
PROBE=$HERE/hypr-option.lua
DEFAULTS=$HERE/hypr-omarchy-defaults.lua
. "$HERE/hypr-live.sh"
BEGIN="-- >>> Managed by loadout (omarchy-close-window-key)"
END="-- <<< Managed by loadout (omarchy-close-window-key)"

# "SUPER + Q" and "super+q" are the same key: compare without spaces, upper.
norm() {
  tr -d ' ' | tr '[:lower:]' '[:upper:]'
}

# Keys Omarchy's own defaults bind to the close action, other than KEY, as
# the defaults wrote them. Fails when the defaults can't be evaluated.
omarchy_keys() {
  keys=$(lua "$PROBE" "action:$ACTION" "$DEFAULTS") || return 1
  [ "$keys" = nil ] && return 0
  printf '%s\n' "$keys" | while IFS= read -r k; do
    [ "$(printf '%s' "$k" | norm)" = "$(printf '%s' "$KEY" | norm)" ] || printf '%s\n' "$k"
  done
}

# KEY runs exactly the close action, and none of Omarchy's keys still does.
in_place() {
  defaults=$(omarchy_keys) || return 1
  [ "$(lua "$PROBE" "bind:$KEY")" = "$ACTION" ] || return 1
  closing=$(lua "$PROBE" "action:$ACTION") || return 1
  closing=$(printf '%s\n' "$closing" | norm)
  for k in $(printf '%s\n' "$defaults" | norm); do
    printf '%s\n' "$closing" | grep -qxF "$k" && return 1
  done
  return 0
}

block() {
  echo "$BEGIN"
  echo "-- SUPER+Q closes the window instead of Omarchy's key for it"
  echo "-- (scripts/maintain/omarchy-close-window-key.sh rewrites this block)."
  printf '%s\n' "$1" | while IFS= read -r k; do
    [ -n "$k" ] && echo "hl.unbind(\"$k\")"
  done
  echo "hl.unbind(\"$KEY\")"
  echo "o.bind(\"$KEY\", \"Close window\", hl.dsp.window.close())"
  echo "$END"
}

case "${1:-install}" in
check)
  in_place
  ;;
install)
  keys=$(omarchy_keys) || exit 1
  mkdir -p "$(dirname "$CONF")"
  touch "$CONF"
  # The file without the old block (between the markers) and its trailing
  # blank lines, then the current block.
  rest=$(awk -v b="$BEGIN" -v e="$END" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' "$CONF")
  { printf '%s\n\n' "$rest"; block "$keys"; } > "$CONF"
  in_place || { echo "$KEY doesn't close windows alone after $CONF: something loaded later binds it or one of Omarchy's close keys" >&2; exit 1; }
  sig=$(live_instance)
  if [ -n "$sig" ]; then
    HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl -q reload
    # Every "Close window" binding in the running Hyprland: just KEY
    # (modmask 64 = SUPER alone).
    live=$(HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl binds -j |
      jq -r '[.[] | select(.description == "Close window") | "\(.modmask) \(.key)"] | join("|")')
    [ "$live" = "64 Q" ] ||
      { echo "the running Hyprland's Close window bindings are '$live', not '64 Q'" >&2; exit 1; }
  else
    echo "Hyprland isn't reachable from here; the keys change at the next login."
  fi
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
