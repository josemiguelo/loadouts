#!/bin/sh
# Development libraries bundle. Single source of truth for the package list:
# loadout runs `sh scripts/development-libs.sh check` as the version check and
# `file:scripts/development-libs.sh` (no argument -> install) as the installer.
set -eu

# Queried by package name with rpm -q:
PKGS="dbus-devel konsole"
# Virtual provides: dnf resolves them on install, but rpm needs --whatprovides:
PROVIDES="dnf-command(copr)"

case "${1:-install}" in
check)
  rpm -q $PKGS >/dev/null
  for p in $PROVIDES; do
    rpm -q --whatprovides "$p" >/dev/null
  done
  # All present -> report the representative version:
  rpm -q dbus-devel
  ;;
install)
  sudo dnf install -y $PKGS $PROVIDES
  ;;
*)
  echo "usage: $0 [check|install]" >&2
  exit 2
  ;;
esac
