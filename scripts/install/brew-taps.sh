#!/bin/sh
# Third-party taps the manifest installs from, tapped AND trusted. Trust is
# per user (~/.homebrew/trust.json), so a tap another account trusted still
# fails here with "Refusing to load ... from untrusted tap". Single source of
# truth: add a tap to TAPS and both check and install follow.
set -eu

BREW="sh scripts/install/brew.sh"

TAPS="tmuxpack/tpack
raine/workmux
anomalyco/tap"

each() {
  echo "$TAPS" | while read -r tap; do
    [ -n "$tap" ] || continue
    "$1" "$tap" || exit 1
  done
}

trusted() { $BREW tap-info "$1" 2>/dev/null | grep -qx Trusted; }
check_one() { trusted "$1"; }
install_one() {
  $BREW tap-info "$1" 2>/dev/null | grep -q "Installed" || $BREW tap "$1"
  trusted "$1" || $BREW trust --tap "$1"
}

case "${1:-install}" in
  check) each check_one ;;
  install) each install_one ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
