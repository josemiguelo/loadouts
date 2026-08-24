#!/bin/sh
# Dotfiles maintenance: pull + apply (`chezmoi update`). The check is real
# drift truth — `chezmoi verify` hashes actual files against the target
# state; on drift it lists what differs (`chezmoi status`) as the detail.
# Modes: `check` / `install` (default).
set -eu

SOURCE="$HOME/.local/share/chezmoi"
MODE="${1:-install}"
case "$MODE" in
check | install) ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac

if [ "$MODE" = "check" ]; then
  [ -d "$SOURCE" ] || { echo "missing: dotfiles not initialized ($SOURCE)"; exit 1; }
  if ! chezmoi verify; then
    echo "missing: dotfiles drifted from the chezmoi target state:"
    chezmoi status
    exit 1
  fi
  exit 0
fi

# --no-tty: on a conflict (file modified outside chezmoi) fail with the
# reason instead of prompting — a prompt would hang under maintain's
# captured output. Resolve with `chezmoi diff`, then rerun.
chezmoi update --verbose --no-tty
