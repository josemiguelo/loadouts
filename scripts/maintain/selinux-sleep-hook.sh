#!/bin/sh
# Local SELinux module letting systemd-sleep exec its hooks without an AVC
# (see selinux/omedora-sleep.cil). Loaded straight from CIL, so no
# checkmodule/semodule_package step. `semodule -l` needs root, so the check
# reads the copy install keeps under /etc/selinux/loadout instead of the
# policy store; a module removed by hand behind that file goes unnoticed
# until the next AVC.
# Modes: `check` / `install` (default).
set -eu

SRC="scripts/maintain/selinux/omedora-sleep.cil"
DEST="/etc/selinux/loadout/omedora-sleep.cil"
PRIORITY=300

case "${1:-install}" in
  check)
    [ "$(cat "$DEST" 2>/dev/null)" = "$(cat "$SRC")" ]
    ;;
  install)
    command -v semodule >/dev/null || { echo "semodule not found (policycoreutils)" >&2; exit 1; }
    if [ "$(cat "$DEST" 2>/dev/null)" != "$(cat "$SRC")" ]; then
      sudo install -Dm644 "$SRC" "$DEST"
      sudo semodule -X "$PRIORITY" -i "$DEST"
    fi
    ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
