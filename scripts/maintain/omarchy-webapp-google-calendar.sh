#!/bin/sh
# Google Calendar as an Omarchy web app (its own app window), with Omarchy's
# own omarchy-webapp-install.
# Modes: `check` / `install` (default).
set -eu

DESKTOP="$HOME/.local/share/applications/Google Calendar.desktop"
URL=https://calendar.google.com/
ICON=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/google-calendar.png

ready() {
  grep -q "^Exec=omarchy-launch-webapp.*calendar\.google\.com" "$DESKTOP" 2>/dev/null
}

case "${1:-install}" in
check)
  ready
  ;;
install)
  omarchy-webapp-install "Google Calendar" "$URL" "$ICON"
  ready || { echo "Google Calendar web app not in place after install" >&2; exit 1; }
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
