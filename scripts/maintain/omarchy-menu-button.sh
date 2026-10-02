#!/bin/sh
# The menu button as a real icon: omarchy-menu-button/plugin is an Omarchy
# shell bar widget drawing the Omarchy logo (icons/omarchy.svg, with the
# shared bar-icon files from omarchy-bar-icons-lib.sh), followed by
# Keystroke's bar items. It takes the place of Keystroke's
# own bar widget: Keystroke's entry in ~/.config/omarchy/shell.json moves from
# the bar layout to plugins[], which keeps it enabled as the menu. The widget
# is installed into ~/.config/omarchy/plugins/ and enabled; its place on the
# bar comes from omarchy-bar-widgets. The check compares the plugin with the
# repo's, requires it enabled, and Keystroke enabled but off the bar.
# Modes: `check` / `install` (default).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/omarchy-bar-icons-lib.sh"
SRC=$HERE/omarchy-menu-button/plugin
PLUGIN_ID=josemiguelo.menu-button
PLUGIN_DIR=$HOME/.config/omarchy/plugins/$PLUGIN_ID
PLUGIN_FILES="manifest.json MenuButton.qml"
KEYSTROKE=evindor.keystroke
JSON=$HOME/.config/omarchy/shell.json

plugin_copied() {
  for f in $PLUGIN_FILES; do
    [ -f "$PLUGIN_DIR/$f" ] && cmp -s "$SRC/$f" "$PLUGIN_DIR/$f" || return 1
  done
  bar_icons_same "$PLUGIN_DIR"
}

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
  plugin_copied && enabled "$PLUGIN_ID" && keystroke_in_plugins && ! keystroke_on_bar
}

case "${1:-install}" in
check)
  in_place
  ;;
install)
  enabled "$KEYSTROKE" || keystroke_in_plugins || { echo "$KEYSTROKE isn't installed and enabled: it comes from omarchy-plugins" >&2; exit 1; }
  changed=no
  plugin_copied || changed=yes
  for f in $PLUGIN_FILES; do
    mkdir -p "$(dirname "$PLUGIN_DIR/$f")"
    cp "$SRC/$f" "$PLUGIN_DIR/$f"
  done
  bar_icons_copy "$PLUGIN_DIR"
  # Enabling goes through the running shell, which learns of a new plugin a
  # moment after the rescan.
  omarchy-shell shell rescanPlugins >/dev/null
  tries=0
  until enabled "$PLUGIN_ID" || omarchy plugin enable "$PLUGIN_ID" >/dev/null 2>&1; do
    tries=$((tries + 1))
    [ "$tries" -lt 10 ] || { echo "couldn't enable the $PLUGIN_ID shell plugin (is omarchy-shell running?)" >&2; exit 1; }
    sleep 0.5
  done
  if keystroke_on_bar; then
    tmp=$(mktemp "$JSON.XXXXXX")
    jq --arg id "$KEYSTROKE" '
      .bar.layout |= map_values(map(select(.id != $id)))
      | .plugins = ((.plugins // []) | if any(.[]; .id == $id) then . else . + [{ id: $id }] end)' "$JSON" > "$tmp"
    mv "$tmp" "$JSON"
  fi
  # A loaded plugin keeps its old QML, even across disable/enable, until the
  # shell restarts.
  if [ "$changed" = yes ]; then
    restart_shell_settled "$PLUGIN_ID"
  fi
  # A restarted shell answers `omarchy plugin list` a moment later.
  tries=0
  until in_place; do
    tries=$((tries + 1))
    [ "$tries" -lt 20 ] || { echo "$PLUGIN_ID isn't in place after install" >&2; exit 1; }
    sleep 0.5
  done
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
