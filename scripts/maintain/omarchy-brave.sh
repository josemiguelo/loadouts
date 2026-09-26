#!/bin/sh
# Brave, set up by Omarchy's own installer (`omarchy install browser brave`):
# the AUR's brave-bin, Omarchy's managed-policy directory, Omarchy's Chromium
# flags (~/.config/brave-flags.conf) and the Omarchy theme. It doesn't change
# the default browser (omarchy-default-browser-arch does that).
# Modes: `check` / `install` (default).
set -eu

ready() {
  pacman -Q brave-bin >/dev/null 2>&1 &&
    [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/brave-flags.conf" ] &&
    [ -d /etc/brave/policies/managed ]
}

case "${1:-install}" in
check)
  ready
  ;;
install)
  omarchy install browser brave
  ready || { echo "Brave isn't fully set up" >&2; exit 1; }
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
