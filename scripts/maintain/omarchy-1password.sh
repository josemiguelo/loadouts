#!/bin/sh
# 1Password, set up by Omarchy's own installer
# (omarchy-install-service-1password): the app and the CLI from Omarchy's
# repo, plus the managed-extension entry that makes Chromium install the
# 1Password extension. The installer also opens 1Password when it's done.
#
# 1Password reads the display scale itself and, on a scaled monitor, draws
# its contents larger than the windows it asks for: Quick Access comes up
# cut off. Omarchy's launcher passes --force-device-scale-factor=1; so do
# the login autostart entry 1Password writes (its "Start at login", rewritten
# here when it lacks the flag, never created) and Ctrl+Shift+Space, which
# opens Quick Access from a block in ~/.config/hypr/bindings.lua — Wayland
# gives 1Password no global shortcut of its own.
# Modes: `check` / `install` (default).
set -eu

EXTENSION=/usr/share/chromium/extensions/aeblfdkhhhdcdjpifhhbdiojplfjncoa.json
AUTOSTART=$HOME/.config/autostart/com.onepassword.OnePassword.desktop
FLAG=--force-device-scale-factor=1
CONF=$HOME/.config/hypr/bindings.lua
HERE="$(cd "$(dirname "$0")" && pwd)"
PROBE=$HERE/hypr-option.lua
. "$HERE/hypr-live.sh"
BEGIN="-- >>> Managed by loadout (omarchy-1password)"
END="-- <<< Managed by loadout (omarchy-1password)"
KEY="CTRL + SHIFT + SPACE"
QUICK_ACCESS="1password $FLAG --quick-access"
# modmask: CTRL 4 + SHIFT 1.
MASK=5

block() {
  echo "$BEGIN"
  echo "-- Ctrl+Shift+Space opens 1Password's Quick Access"
  echo "-- (scripts/maintain/omarchy-1password.sh rewrites this block)."
  echo "hl.unbind(\"$KEY\")"
  echo "o.bind(\"$KEY\", \"1Password Quick Access\", o.launch(\"$QUICK_ACCESS\"))"
  echo "$END"
}

current() {
  [ -f "$CONF" ] || return 0
  awk -v b="$BEGIN" -v e="$END" '$0 == b { keep = 1 } keep { print } $0 == e { keep = 0 }' "$CONF"
}

installed() {
  pacman -Q 1password 1password-cli >/dev/null 2>&1 &&
    # The extension entry only matters where Chromium is installed.
    { ! command -v chromium >/dev/null 2>&1 || [ -f "$EXTENSION" ]; }
}

# No autostart entry (start at login off) is fine; one without the flag isn't.
autostart_scaled() {
  [ ! -f "$AUTOSTART" ] || grep -q "^Exec=.*$FLAG" "$AUTOSTART"
}

bound() {
  [ "$(current)" = "$(block)" ] && [ "$(lua "$PROBE" "bind:$KEY")" = "uwsm-app -- $QUICK_ACCESS" ]
}

ready() {
  installed && autostart_scaled && bound
}

case "${1:-install}" in
check)
  ready
  ;;
install)
  installed || omarchy-install-service-1password
  installed || { echo "1Password isn't fully set up" >&2; exit 1; }
  if ! autostart_scaled; then
    sed -i "s|^Exec=\([^ ]*1password\)|Exec=\1 $FLAG|" "$AUTOSTART"
  fi
  touch "$CONF"
  rest=$(awk -v b="$BEGIN" -v e="$END" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' "$CONF")
  { printf '%s\n\n' "$rest"; block; } > "$CONF"
  ready || { echo "1Password's autostart flag or Quick Access key isn't in place after install" >&2; exit 1; }
  sig=$(live_instance)
  if [ -n "$sig" ]; then
    HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl -q reload
    errors=$(HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl configerrors | grep -v '^[[:space:]]*$' || true)
    [ -z "$errors" ] || { echo "Hyprland reports config errors after the reload: $errors" >&2; exit 1; }
    got=$(HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl binds -j | jq -r --argjson m "$MASK" \
      '[.[] | select(.modmask == $m and .key == "SPACE") | .description] | join("|")')
    [ "$got" = "1Password Quick Access" ] ||
      { echo "the running Hyprland binds Ctrl+Shift+Space to '$got', not '1Password Quick Access'" >&2; exit 1; }
  else
    echo "Hyprland isn't reachable from here; the key works at the next login."
  fi
  echo "A 1Password already running keeps its scale until it restarts."
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
