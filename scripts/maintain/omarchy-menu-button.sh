#!/bin/sh
# The menu button (josemiguelo.menu-button, installed by omarchy-bar-icons:
# the Omarchy logo as an icon, followed by Keystroke's bar items) in the place
# of Keystroke's own bar widget: Keystroke's entry in
# ~/.config/omarchy/shell.json moves from the bar layout to plugins[], which
# keeps it enabled as the menu. The check: the menu button enabled, Keystroke
# enabled but off the bar.
# Modes: `check` / `install` (default).
set -eu

BUTTON=josemiguelo.menu-button
KEYSTROKE=evindor.keystroke
JSON=$HOME/.config/omarchy/shell.json

enabled() {
  omarchy plugin list --json 2>/dev/null |
    jq -e --arg id "$1" 'any(.[]; .id == $id and .enabled)' >/dev/null
}

keystroke_on_bar() {
  [ -f "$JSON" ] && jq -e --arg id "$KEYSTROKE" 'any(.bar.layout[]?[]?; .id == $id)' "$JSON" >/dev/null
}

# `omarchy plugin list` only counts a bar widget on the bar; off it, Keystroke
# is enabled by its plugins[] entry.
keystroke_in_plugins() {
  [ -f "$JSON" ] && jq -e --arg id "$KEYSTROKE" 'any(.plugins[]?; .id == $id)' "$JSON" >/dev/null
}

in_place() {
  enabled "$BUTTON" && keystroke_in_plugins && ! keystroke_on_bar
}

case "${1:-install}" in
check)
  in_place
  ;;
install)
  enabled "$KEYSTROKE" || keystroke_in_plugins || { echo "$KEYSTROKE isn't installed and enabled: it comes from omarchy-plugins" >&2; exit 1; }
  enabled "$BUTTON" || { echo "$BUTTON isn't installed and enabled: it comes from omarchy-bar-icons" >&2; exit 1; }
  if keystroke_on_bar; then
    tmp=$(mktemp "$JSON.XXXXXX")
    jq --arg id "$KEYSTROKE" '
      .bar.layout |= map_values(map(select(.id != $id)))
      | .plugins = ((.plugins // []) | if any(.[]; .id == $id) then . else . + [{ id: $id }] end)' "$JSON" > "$tmp"
    mv "$tmp" "$JSON"
  fi
  in_place || { echo "Keystroke is still on the bar after install" >&2; exit 1; }
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
