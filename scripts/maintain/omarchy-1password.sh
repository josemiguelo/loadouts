#!/bin/sh
# 1Password, set up by Omarchy's own installer
# (omarchy-install-service-1password): the app and the CLI from Omarchy's
# repo, plus the managed-extension entry that makes Chromium install the
# 1Password extension. The installer also opens 1Password when it's done.
# Modes: `check` / `install` (default).
set -eu

EXTENSION=/usr/share/chromium/extensions/aeblfdkhhhdcdjpifhhbdiojplfjncoa.json

ready() {
  pacman -Q 1password 1password-cli >/dev/null 2>&1 &&
    # The extension entry only matters where Chromium is installed.
    { ! command -v chromium >/dev/null 2>&1 || [ -f "$EXTENSION" ]; }
}

case "${1:-install}" in
check)
  ready
  ;;
install)
  omarchy-install-service-1password
  ready || { echo "1Password isn't fully set up" >&2; exit 1; }
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
