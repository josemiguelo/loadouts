#!/bin/sh
# DNF performance/behavior tweaks in /etc/dnf/dnf.conf. Single source of
# truth: add a line to LINES and both check and install follow.
set -eu

DNF_CONF="/etc/dnf/dnf.conf"

LINES="fastestmirror=True
max_parallel_downloads=10
defaultyes=True
keepcache=True"

each() {
  echo "$LINES" | while read -r line; do
    [ -n "$line" ] || continue
    "$1" "$line" || exit 1
  done
}

check_one() { grep -qxF "$1" "$DNF_CONF"; }
install_one() {
  if ! grep -qxF "$1" "$DNF_CONF"; then
    echo "$1" | sudo tee -a "$DNF_CONF" >/dev/null
  fi
}

case "${1:-install}" in
  check) each check_one ;;
  install) each install_one ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
