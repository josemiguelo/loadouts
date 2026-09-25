#!/bin/sh
# Firefox, set up by Omarchy's own installer (`omarchy install browser
# firefox`): the package, Omarchy's browser policy in Firefox's distribution
# directory, and MOZ_ENABLE_WAYLAND=1 for the session (environment.d, read at
# the next login). Making it the default browser is a separate step.
# Modes: `check` / `install` (default).
set -eu

POLICY=/usr/lib/firefox/distribution/policies.json
WAYLAND="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/omarchy-firefox-wayland.conf"

ready() {
  pacman -Q firefox >/dev/null 2>&1 && [ -f "$POLICY" ] && [ -f "$WAYLAND" ]
}

case "${1:-install}" in
check)
  ready
  ;;
install)
  omarchy install browser firefox
  ready || { echo "Firefox isn't fully set up" >&2; exit 1; }
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
