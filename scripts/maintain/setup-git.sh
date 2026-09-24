#!/bin/sh
# Global git identity + delta/merge config. The name is the same on every
# machine; the email only fills a gap, since a work machine sets its own.
#
# Written to ~/.gitconfig by name, never with `--global`: that writes to
# ~/.config/git/config whenever ~/.gitconfig doesn't exist yet — on Omarchy
# that's Omarchy's own file, which `omarchy-reinstall-configs` puts back to
# its defaults. git reads both, and ~/.gitconfig wins a key they share.
#
# Read by name too: once ~/.gitconfig exists, `git config --global` reads
# ONLY that file, so Omarchy's identity in ~/.config/git/config would look
# unset and get overwritten.
# Modes: `check` / `install` (default).
set -eu

DESIRED_EMAIL="josemiguelo.ochoa@gmail.com"
DESIRED_NAME="Jose Miguel Ochoa"
GITCONFIG="$HOME/.gitconfig"
XDG_GITCONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/git/config"

# A key's global value as git itself resolves it: ~/.gitconfig first.
global_get() {
  git config --file "$GITCONFIG" --get "$1" 2>/dev/null ||
    git config --file "$XDG_GITCONFIG" --get "$1" 2>/dev/null ||
    true
}

case "${1:-install}" in
check)
  [ -n "$(global_get user.email)" ] &&
    [ "$(global_get user.name)" = "$DESIRED_NAME" ] &&
    [ "$(global_get core.pager)" = delta ] &&
    [ "$(global_get merge.conflictStyle)" = zdiff3 ]
  ;;
install)
  [ -n "$(global_get user.email)" ] || git config --file "$GITCONFIG" user.email "$DESIRED_EMAIL"
  # In ~/.gitconfig even when Omarchy's installer set another: this one wins.
  git config --file "$GITCONFIG" user.name "$DESIRED_NAME"
  git config --file "$GITCONFIG" core.pager delta
  git config --file "$GITCONFIG" interactive.diffFilter 'delta --color-only'
  git config --file "$GITCONFIG" delta.navigate true
  git config --file "$GITCONFIG" merge.conflictStyle zdiff3
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
