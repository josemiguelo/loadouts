#!/bin/sh
# The activity monitor (SUPER+CTRL+T: omarchy-launch-tui btop, window class
# org.omarchy.btop) at the machine's size instead of 875x600, the size
# Omarchy gives every window tagged floating-window (default/hypr/apps/
# system.lua), btop among them. A window rule in ~/.config/hypr/hyprland.lua,
# where Omarchy puts personal additions: it matches the tag as well as the
# class because Hyprland applies tag-matched rules after class-only ones — a
# class-only rule loses to Omarchy's, tried live. Only btop changes; the
# other floating windows keep Omarchy's size. The check doesn't read the
# file's text: hypr-option.lua evaluates the whole Lua config and lists every
# window rule that sets a size; the last floating-window one that can match
# btop must be this size. Install rewrites the block between its markers.
# A size is pixels (1400) or a share of the monitor (80%), which becomes a
# Hyprland expression — (monitor_w*0.8) — the form Omarchy's own webcam
# overlay rule uses, so it follows whatever screen the window opens on.
# usage: omarchy-activity-monitor-size.sh [check] <width> <height>
set -eu

MODE=install
if [ "${1:-}" = check ]; then MODE=check; shift; fi
W=${1:?usage: $0 [check] <width> <height>}
H=${2:?usage: $0 [check] <width> <height>}

# 80% on axis w -> (monitor_w*0.8); pixels stay as they are.
size_of() {
  case $1 in
  *%) awk -v p="${1%\%}" -v axis="$2" 'BEGIN { printf "(monitor_%s*%g)\n", axis, p / 100 }' ;;
  *) printf '%s\n' "$1" ;;
  esac
}

# As a Lua value: an expression is a string, pixels a number.
lua_of() {
  case $1 in
  \(*) printf '"%s"\n' "$1" ;;
  *) printf '%s\n' "$1" ;;
  esac
}

SW=$(size_of "$W" w)
SH=$(size_of "$H" h)

CLASS=org.omarchy.btop
TAG=floating-window
CONF=$HOME/.config/hypr/hyprland.lua
HERE="$(cd "$(dirname "$0")" && pwd)"
PROBE=$HERE/hypr-option.lua
. "$HERE/hypr-live.sh"
BEGIN="-- >>> Managed by loadout (omarchy-activity-monitor-size)"
END="-- <<< Managed by loadout (omarchy-activity-monitor-size)"

# The size the last floating-window rule that can match btop sets: tag
# rules win over class-only ones, and the last such rule wins among them.
effective() {
  rules=$(lua "$PROBE" rules:size) || return 1
  printf '%s\n' "$rules" | while IFS="$(printf '\t')" read -r class tag value; do
    [ "$tag" = "$TAG" ] || continue
    if [ -z "$class" ] || printf '%s' "$CLASS" | grep -Eq -- "$class"; then
      printf '%s\n' "$value"
    fi
  done | tail -n1
}

sized() {
  [ "$(effective)" = "$SW $SH" ]
}

block() {
  echo "$BEGIN"
  echo "-- The activity monitor (SUPER+CTRL+T, btop) at $W by $H, not Omarchy's"
  echo "-- floating-window size. Matches the tag too: tag rules apply after"
  echo "-- class-only ones (scripts/maintain/omarchy-activity-monitor-size.sh)."
  echo "o.window({ class = \"^(org\\\\.omarchy\\\\.btop)\$\", tag = \"$TAG\" }, { size = { $(lua_of "$SW"), $(lua_of "$SH") } })"
  echo "$END"
}

case "$MODE" in
check)
  sized
  ;;
install)
  lua "$PROBE" rules:size >/dev/null || exit 1
  rest=$(awk -v b="$BEGIN" -v e="$END" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' "$CONF")
  { printf '%s\n\n' "$rest"; block; } > "$CONF"
  sized || { echo "btop's floating size is '$(effective)', not '$SW $SH', after $CONF: a later rule sets it" >&2; exit 1; }
  sig=$(live_instance)
  if [ -n "$sig" ]; then
    HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl -q reload
    errors=$(HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl configerrors | grep -v '^[[:space:]]*$' || true)
    [ -z "$errors" ] || { echo "Hyprland reports config errors after the reload: $errors" >&2; exit 1; }
    echo "Applies to activity monitors opened from now on."
  else
    echo "Hyprland isn't reachable from here; applies at the next login."
  fi
  ;;
esac
