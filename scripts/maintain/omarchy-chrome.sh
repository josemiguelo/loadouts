#!/bin/sh
# Google Chrome, set up by Omarchy's own installer (`omarchy install browser
# chrome`): the AUR's google-chrome, Omarchy's managed-policy directory,
# Omarchy's Chromium flags (~/.config/chrome-flags.conf), its copy-URL and
# yt-dlp helpers, and the Omarchy theme. It doesn't change the default
# browser (omarchy-default-browser-arch does that).
# Modes: `check` / `install` (default).
set -eu

ready() {
  pacman -Q google-chrome >/dev/null 2>&1 &&
    [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/chrome-flags.conf" ] &&
    [ -d /etc/opt/chrome/policies/managed ]
}

case "${1:-install}" in
check)
  ready
  ;;
install)
  omarchy install browser chrome
  ready || { echo "Chrome isn't fully set up" >&2; exit 1; }
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
