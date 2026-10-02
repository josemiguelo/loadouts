#!/bin/sh
# Bar widgets drawing SVG icons instead of glyphs, with
# github.com/josemiguelo/omarchy-bar-icons: its bin/omarchy-bar-icons rebuilds
# each widget the opt-in names (one plugin id per word) from its source with
# the repo's patch, or installs the repo's own widgets, and checks them; see
# its README. The repo is the checkout in
# ~/Repos/gh/josemiguelo/omarchy-bar-icons, cloned when missing; install
# fast-forwards it first while it is clean and on master, and leaves local
# work alone otherwise.
# usage: omarchy-bar-icons.sh [check] <id>...
set -eu

REPO=git@github.com:josemiguelo/omarchy-bar-icons.git
CHECKOUT=$HOME/Repos/gh/josemiguelo/omarchy-bar-icons
TOOL=$CHECKOUT/bin/omarchy-bar-icons

if [ "${1:-}" = check ]; then
  [ -x "$TOOL" ] || exit 1
  exec "$TOOL" "$@"
fi

if [ ! -d "$CHECKOUT/.git" ]; then
  mkdir -p "$(dirname "$CHECKOUT")"
  git clone --quiet "$REPO" "$CHECKOUT"
elif [ "$(git -C "$CHECKOUT" branch --show-current)" = master ] && [ -z "$(git -C "$CHECKOUT" status --porcelain)" ]; then
  git -C "$CHECKOUT" pull --quiet --ff-only ||
    echo "couldn't fast-forward $CHECKOUT; using it as it is" >&2
fi
exec "$TOOL" "$@"
