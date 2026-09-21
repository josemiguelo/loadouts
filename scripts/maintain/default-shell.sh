#!/bin/sh
# Login shell for the current user: the zsh the package manager installed.
# usermod rather than chsh so it never prompts for a password (loadout runs
# this under captured output and asks for sudo itself).
# Modes: `check` (login shell already zsh?) / `install` (default).
set -eu

ZSH=$(command -v zsh) || { echo "zsh is not installed" >&2; exit 1; }

current_shell() {
  if [ "$(uname -s)" = "Darwin" ]; then
    dscl . -read "/Users/$USER" UserShell | awk '{print $2}'
  else
    getent passwd "$USER" | cut -d: -f7
  fi
}

case "${1:-install}" in
  check)
    [ "$(current_shell)" = "$ZSH" ]
    ;;
  install)
    grep -qxF "$ZSH" /etc/shells || { echo "$ZSH is not listed in /etc/shells" >&2; exit 1; }
    if [ "$(current_shell)" != "$ZSH" ]; then
      if [ "$(uname -s)" = "Darwin" ]; then
        sudo chsh -s "$ZSH" "$USER"
      else
        sudo usermod -s "$ZSH" "$USER"
      fi
      echo "login shell set to $ZSH; takes effect on next login"
    fi
    ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
