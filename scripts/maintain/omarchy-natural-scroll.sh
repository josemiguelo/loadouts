#!/bin/sh
# Natural (inverse) touchpad scrolling, the Omarchy way: an override in
# ~/.config/hypr/input.lua, the file Omarchy keeps for personal input
# settings. It's loaded after Omarchy's defaults (default/hypr/input.lua sets
# natural_scroll = false), and Omarchy updates leave it alone.
# The check doesn't read the file's text: hypr-option.lua evaluates the whole
# Lua config and reports the value Hyprland would end up with, so a comment,
# a dead branch or a later `false` can't fool it. No session needed.
# Install adds the override only when that value isn't true, then confirms it
# in the running Hyprland when there is one.
# Modes: `check` / `install` (default).
set -eu

CONF=$HOME/.config/hypr/input.lua
HERE="$(cd "$(dirname "$0")" && pwd)"
PROBE=$HERE/hypr-option.lua
. "$HERE/hypr-live.sh"

# The value the config produces; fails (the probe says why) when the config
# can't be evaluated — never read as "not set".
value() {
  lua "$PROBE" input.touchpad.natural_scroll
}

case "${1:-install}" in
check)
  [ "$(value)" = true ]
  ;;
install)
  now=$(value) || exit 1
  # Once is enough: if our line is there and still loses, adding it again
  # won't win either — the check below says what to look at.
  if [ "$now" != true ] && ! grep -qs 'natural_scroll = true } } })' "$CONF"; then
    mkdir -p "$(dirname "$CONF")"
    cat >> "$CONF" <<'LUA'

-- Natural (inverse) touchpad scrolling. Managed by loadout
-- (scripts/maintain/omarchy-natural-scroll.sh).
hl.config({ input = { touchpad = { natural_scroll = true } } })
LUA
  fi
  # Appended last in input.lua, it still loses to anything later in the
  # chain (hyprland.lua after require("hypr.input")): say so, don't pass.
  now=$(value) || exit 1
  [ "$now" = true ] || {
    echo "natural_scroll is still not true after $CONF: something loaded later sets it — see ~/.config/hypr/hyprland.lua" >&2
    exit 1
  }
  sig=$(live_instance)
  if [ -n "$sig" ]; then
    HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl -q reload
    live=$(HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl getoption input:touchpad:natural_scroll | head -n1)
    [ "$live" = "bool: true" ] || {
      echo "the config says natural_scroll = true but the running Hyprland reports '$live'" >&2
      exit 1
    }
  else
    echo "Hyprland isn't reachable from here; natural scrolling applies at the next login."
  fi
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
