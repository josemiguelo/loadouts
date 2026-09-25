#!/bin/sh
# Omarchy launches terminals through xdg-terminal-exec; omarchy-default-terminal
# writes the preference file (~/.config/xdg-terminals.list) it reads.
# Modes: `check` (kitty already first?) / `install` (default).
set -eu

WANT="kitty"

current() {
  xdg-terminal-exec --print-id 2>/dev/null | cut -d: -f1
}

case "${1:-install}" in
  check)
    [ "$(current)" = "$WANT.desktop" ]
    ;;
  install)
    omarchy-default-terminal "$WANT"
    ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
