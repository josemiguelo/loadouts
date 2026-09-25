#!/bin/sh
# VS Code, set up by Omarchy's own installer (omarchy-install-editor-vscode):
# Omarchy's build (visual-studio-code-bin), libsecret for its keyring,
# VS Code's self-update turned off (pacman updates it), and Omarchy's theme.
# The installer WRITES ~/.config/Code/User/settings.json (update.mode only)
# and opens VS Code when it's done — the check keeps that to the first run.
# Modes: `check` / `install` (default).
set -eu

ARGV="$HOME/.vscode/argv.json"

ready() {
  pacman -Q visual-studio-code-bin >/dev/null 2>&1 && grep -q gnome-libsecret "$ARGV" 2>/dev/null
}

case "${1:-install}" in
check)
  ready
  ;;
install)
  omarchy-install-editor-vscode
  ready || { echo "VS Code isn't fully set up" >&2; exit 1; }
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
