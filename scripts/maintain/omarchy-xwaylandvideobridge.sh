#!/bin/sh
# Hide KDE's xwaylandvideobridge under Hyprland. The bridge lets X11 apps
# screen-share on Wayland by mirroring PipeWire into an X window that KWin
# knows to hide; Hyprland shows it as a black, unfocusable window on every
# login. Same rule set the bridge's own README recommends for Hyprland,
# written as an Omarchy Lua module and required from ~/.config/hypr/hyprland.lua
# (the file Omarchy reserves for personal config), so package updates that
# refresh the other hypr files never touch it.
#
# Rule names checked against https://wiki.hypr.land/Configuring/Basics/Window-Rules/
# Modes: `check` / `install` (default).
set -eu

HYPR="$HOME/.config/hypr"
MODULE="$HYPR/xwaylandvideobridge.lua"
MAIN="$HYPR/hyprland.lua"
REQUIRE='require("hypr.xwaylandvideobridge")'
WANT='-- Managed by loadout (scripts/maintain/omarchy-xwaylandvideobridge.sh).
-- KDE'"'"'s Xwayland Video Bridge: keep it for X11 screen sharing, never show it.
o.window("^(xwaylandvideobridge)$", {
  float = true,
  size = { 1, 1 },
  opacity = "0.0 override",
  no_anim = true,
  no_blur = true,
  no_focus = true,
  no_initial_focus = true,
})'

case "${1:-install}" in
  check)
    [ "$(cat "$MODULE" 2>/dev/null)" = "$WANT" ] && grep -qxF "$REQUIRE" "$MAIN"
    ;;
  install)
    [ -f "$MAIN" ] || { echo "$MAIN not found: is Omarchy provisioned for this user?" >&2; exit 1; }
    if [ "$(cat "$MODULE" 2>/dev/null)" != "$WANT" ]; then
      printf '%s\n' "$WANT" >"$MODULE"
    fi
    if ! grep -qxF "$REQUIRE" "$MAIN"; then
      printf '\n-- Hide KDE'"'"'s xwaylandvideobridge (managed by loadout).\n%s\n' "$REQUIRE" >>"$MAIN"
    fi
    # Reload only inside a running session; a fresh login picks the file up anyway.
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
      hyprctl reload >/dev/null
      errors=$(hyprctl configerrors 2>/dev/null | grep -v '^$' || true)
      [ -z "$errors" ] || { echo "Hyprland config errors:" >&2; echo "$errors" >&2; exit 1; }
      # float/size only apply when a window is created: a bridge that is
      # already up keeps its tile (invisible, but still splitting the layout)
      # until it is restarted.
      if systemctl --user -q is-active 'app-org.kde.xwaylandvideobridge@autostart.service'; then
        systemctl --user restart 'app-org.kde.xwaylandvideobridge@autostart.service'
      fi
    fi
    ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
