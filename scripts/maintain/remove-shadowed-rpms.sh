#!/bin/sh
# rpm packages that must NOT be installed because the brew versions own them.
# Single source of truth: add a package to PKGS and both check and install
# (removal) follow. check passes only when every listed rpm is absent.
set -eu

PKGS="tmux bat"

case "${1:-install}" in
  check)
    for p in $PKGS; do
      if rpm -q "$p" >/dev/null 2>&1; then
        exit 1
      fi
    done
    ;;
  install)
    for p in $PKGS; do
      if rpm -q "$p" >/dev/null 2>&1; then
        sudo dnf remove -y "$p"
      fi
    done
    ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
