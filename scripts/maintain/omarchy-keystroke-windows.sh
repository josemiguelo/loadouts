#!/bin/sh
# Keystroke's Windows extension (every open window, grouped by workspace),
# from a Keystroke checkout until it ships with Keystroke: the checkout's
# extensions/windows is linked into ~/.local/share/keystroke/extensions/,
# where Keystroke loads local extensions, and turned on in
# ~/.config/omarchy/keystroke.json (providers.windows.enabled, the rest of
# the file kept). Hyper+Space (SUPER+CTRL+ALT+SHIFT+SPACE) opens the palette
# on its screen, from a block in ~/.config/hypr/bindings.lua. The check
# reads the link and the setting, and has hypr-option.lua evaluate the whole
# config: the key runs exactly that command. Install confirms the key in the
# running Hyprland when there is one, by description.
# Modes: `check` / `install` (default).
set -eu

CHECKOUT=$HOME/Repos/gh/evindor/keystroke
SRC=$CHECKOUT/extensions/windows
LINK=$HOME/.local/share/keystroke/extensions/windows
SETTINGS=$HOME/.config/omarchy/keystroke.json
CONF=$HOME/.config/hypr/bindings.lua
HERE="$(cd "$(dirname "$0")" && pwd)"
PROBE=$HERE/hypr-option.lua
. "$HERE/hypr-live.sh"
BEGIN="-- >>> Managed by loadout (omarchy-keystroke-windows)"
END="-- <<< Managed by loadout (omarchy-keystroke-windows)"
KEY="SUPER + CTRL + ALT + SHIFT + SPACE"
COMMAND="omarchy-shell shell toggle omarchy.menu '{\"scope\":\"windows\",\"title\":\"Windows\"}'"
# modmask: SUPER 64 + CTRL 4 + ALT 8 + SHIFT 1.
MASK=77

block() {
  echo "$BEGIN"
  echo "-- Hyper+Space opens Keystroke on its Windows screen"
  echo "-- (scripts/maintain/omarchy-keystroke-windows.sh rewrites this block)."
  echo "hl.unbind(\"$KEY\")"
  echo "o.bind(\"$KEY\", \"Windows\", [[$COMMAND]])"
  echo "$END"
}

current() {
  [ -f "$CONF" ] || return 0
  awk -v b="$BEGIN" -v e="$END" '$0 == b { keep = 1 } keep { print } $0 == e { keep = 0 }' "$CONF"
}

linked() {
  [ -L "$LINK" ] && [ "$(readlink "$LINK")" = "$SRC" ] && [ -f "$SRC/extension.json" ]
}

enabled() {
  [ -f "$SETTINGS" ] && jq -e '.providers.windows.enabled == true' "$SETTINGS" >/dev/null 2>&1
}

in_place() {
  linked && enabled && [ "$(current)" = "$(block)" ] && [ "$(lua "$PROBE" "bind:$KEY")" = "$COMMAND" ]
}

case "${1:-install}" in
check)
  in_place
  ;;
install)
  [ -f "$SRC/extension.json" ] || {
    echo "no Windows extension at $SRC: clone https://github.com/evindor/keystroke into $CHECKOUT and check out the branch that has it" >&2
    exit 1
  }
  mkdir -p "$(dirname "$LINK")"
  ln -sfn "$SRC" "$LINK"
  # Keystroke reloads the file when it changes and refuses one without
  # "version"; the new copy replaces the old one in a single rename.
  mkdir -p "$(dirname "$SETTINGS")"
  if [ -f "$SETTINGS" ]; then base=$(cat "$SETTINGS"); else base='{"version":1}'; fi
  tmp=$(mktemp "$SETTINGS.XXXXXX")
  printf '%s' "$base" | jq '.version //= 1 | .providers.windows.enabled = true' > "$tmp"
  mv "$tmp" "$SETTINGS"
  touch "$CONF"
  rest=$(awk -v b="$BEGIN" -v e="$END" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' "$CONF")
  { printf '%s\n\n' "$rest"; block; } > "$CONF"
  in_place || { echo "Hyper+Space doesn't run only the Windows command after $CONF: something loaded later binds it" >&2; exit 1; }
  sig=$(live_instance)
  if [ -n "$sig" ]; then
    HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl -q reload
    errors=$(HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl configerrors | grep -v '^[[:space:]]*$' || true)
    [ -z "$errors" ] || { echo "Hyprland reports config errors after the reload: $errors" >&2; exit 1; }
    got=$(HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl binds -j | jq -r --argjson m "$MASK" \
      '[.[] | select(.modmask == $m and .key == "SPACE") | .description] | join("|")')
    [ "$got" = "Windows" ] || { echo "the running Hyprland binds Hyper+Space to '$got', not 'Windows'" >&2; exit 1; }
  else
    echo "Hyprland isn't reachable from here; the key works at the next login."
  fi
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
