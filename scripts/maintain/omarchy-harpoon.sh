#!/bin/sh
# Per-app hotkeys on Hyper, like Raycast's: omarchy-harpoon/harpoon.lua is
# the engine (deployed as ~/.config/hypr/harpoon.lua, which Hyprland's Lua
# loads as hypr.harpoon) and omarchy-harpoon/bindings.lua the apps and keys,
# kept as a block in ~/.config/hypr/bindings.lua, Omarchy's personal-bindings
# file. Hyper is SUPER+CTRL+ALT+SHIFT, which the keyboard sends from one key
# (Keychron Launcher); Omarchy binds nothing on it. omarchy-harpoon/plugin
# is the Omarchy shell plugin that shows where a jump landed, installed into
# ~/.config/omarchy/plugins/ and enabled. The check compares the engine, the
# block and the plugin with the repo's, requires the plugin enabled, and has
# hypr-option.lua evaluate the whole config: each key runs exactly one
# binding. Install rewrites the block between its markers and confirms the
# keys in the running Hyprland when there is one — by description, since with
# a Lua config hyprctl binds shows a function reference, never the action.
# Modes: `check` / `install` (default).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC=$HERE/omarchy-harpoon
ENGINE=$HOME/.config/hypr/harpoon.lua
CONF=$HOME/.config/hypr/bindings.lua
PROBE=$HERE/hypr-option.lua
. "$HERE/hypr-live.sh"
BEGIN="-- >>> Managed by loadout (omarchy-harpoon)"
END="-- <<< Managed by loadout (omarchy-harpoon)"
HYPER="SUPER + CTRL + ALT + SHIFT"
# modmask: SUPER 64 + CTRL 4 + ALT 8 + SHIFT 1.
MASK=77
PLUGIN_ID=josemiguelo.harpoon-toast
PLUGIN_DIR=$HOME/.config/omarchy/plugins/$PLUGIN_ID
PLUGIN_FILES="manifest.json Toast.qml"

plugin_copied() {
  for f in $PLUGIN_FILES; do
    [ -f "$PLUGIN_DIR/$f" ] && cmp -s "$SRC/plugin/$f" "$PLUGIN_DIR/$f" || return 1
  done
}

plugin_enabled() {
  omarchy plugin list --json 2>/dev/null |
    jq -e --arg id "$PLUGIN_ID" 'any(.[]; .id == $id and .enabled)' >/dev/null
}

block() {
  echo "$BEGIN"
  cat "$SRC/bindings.lua"
  echo "$END"
}

current() {
  [ -f "$CONF" ] || return 0
  awk -v b="$BEGIN" -v e="$END" '$0 == b { keep = 1 } keep { print } $0 == e { keep = 0 }' "$CONF"
}

# The letters bindings.lua binds on Hyper, one per line.
keys() {
  sed -n 's/^harpoon\.bind(hyper \.\. "\([A-Z0-9]*\)".*/\1/p' "$SRC/bindings.lua"
}

# Each key runs exactly the one harpoon binding (a Lua function).
bound() {
  for k in $(keys); do
    [ "$(lua "$PROBE" "bind:$HYPER + $k")" = "<dispatcher>" ] || return 1
  done
}

in_place() {
  [ -f "$ENGINE" ] && cmp -s "$SRC/harpoon.lua" "$ENGINE" && [ "$(current)" = "$(block)" ] && bound &&
    plugin_copied && plugin_enabled
}

case "${1:-install}" in
check)
  in_place
  ;;
install)
  mkdir -p "$(dirname "$CONF")"
  cp "$SRC/harpoon.lua" "$ENGINE"
  touch "$CONF"
  # The file without the old block and its trailing blank lines, then the
  # current block.
  rest=$(awk -v b="$BEGIN" -v e="$END" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' "$CONF")
  { printf '%s\n\n' "$rest"; block; } > "$CONF"
  changed=no
  plugin_copied || changed=yes
  mkdir -p "$PLUGIN_DIR"
  for f in $PLUGIN_FILES; do cp "$SRC/plugin/$f" "$PLUGIN_DIR/$f"; done
  # Enabling goes through the running shell. A loaded plugin keeps its old
  # QML, even across disable/enable, until the shell restarts.
  omarchy-shell shell rescanPlugins >/dev/null
  plugin_enabled || omarchy plugin enable "$PLUGIN_ID" >/dev/null ||
    { echo "couldn't enable the $PLUGIN_ID shell plugin (is omarchy-shell running?)" >&2; exit 1; }
  if [ "$changed" = yes ]; then
    omarchy restart shell >/dev/null 2>&1 || echo "restart the Omarchy shell to load the new $PLUGIN_ID (omarchy restart shell)" >&2
  fi
  in_place || { echo "the Hyper keys don't each run one harpoon binding after $CONF: something loaded later binds them" >&2; exit 1; }
  sig=$(live_instance)
  if [ -n "$sig" ]; then
    HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl -q reload
    errors=$(HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl configerrors | grep -v '^[[:space:]]*$' || true)
    [ -z "$errors" ] || { echo "Hyprland reports config errors after the reload: $errors" >&2; exit 1; }
    live=$(HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl binds -j)
    for k in $(keys); do
      got=$(printf '%s' "$live" | jq -r --argjson m "$MASK" --arg k "$k" \
        '[.[] | select(.modmask == $m and .key == $k) | .description] | join("|")')
      case "$got" in
      *"|"* | "") echo "the running Hyprland binds Hyper+$k to '$got', not one harpoon key" >&2; exit 1 ;;
      esac
    done
  else
    echo "Hyprland isn't reachable from here; the keys work at the next login."
  fi
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
