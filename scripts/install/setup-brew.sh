#!/bin/sh
# Homebrew on Linux, owned by the login user. Single source of truth: the
# prefix and the directories Homebrew itself demands write access to.
#
# check   brew binary present and every DIR writable by $USER
# install install Homebrew if missing (official installer, non-interactive),
#         then chown the prefix to $USER if any part of it is owned by
#         someone else
set -eu

PREFIX="/home/linuxbrew/.linuxbrew"
BREW="$PREFIX/bin/brew"

# The directories `brew install` refuses to run without write access to.
DIRS="Cellar Homebrew bin etc include lib opt sbin share var/homebrew/linked var/homebrew/locks var/log"

writable() {
  [ -x "$BREW" ] || return 1
  for d in $DIRS; do
    [ ! -e "$PREFIX/$d" ] || [ -w "$PREFIX/$d" ] || return 1
  done
}

case "${1:-install}" in
  check)
    writable
    ;;
  install)
    if [ ! -x "$BREW" ]; then
      NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    if [ -n "$(find "$PREFIX" ! -user "$USER" -print -quit 2>/dev/null)" ]; then
      echo "reclaiming $PREFIX for $USER"
      sudo chown -R "$USER" "$PREFIX"
    fi
    writable || { echo "$PREFIX is still not writable by $USER" >&2; exit 1; }
    ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
