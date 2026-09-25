#!/bin/sh
# Default packages (~/.default-npm-packages and ~/.default-gems) present in
# EVERY node and ruby version ~/.config/mise/config.toml pins. mise only seeds
# them into versions it installs from then on, so packages added later need
# this backfill into the versions that already exist.
# Modes: `check` / `install` (default).
# One `npm ls` / `gem list` query per tool version (not per package), run
# concurrently up front — npm boots a node each.
set -eu
command -v mise >/dev/null 2>&1 || { echo "mise not found" >&2; exit 1; }
cd "$HOME"

MODE="${1:-install}"
case "$MODE" in
check | install) ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac

STATUS=0
# The installed versions the global config pins for a tool; missing ones are
# mise-tools' business, not this script's.
versions_of() {
  mise ls --global "$1" 2>/dev/null | awk '$3 != "(missing)" { print $2 }'
}

PROBES=$(mktemp -d)
trap 'rm -rf "$PROBES"' EXIT
if [ -f "$HOME/.default-npm-packages" ]; then
  for v in $(versions_of node); do
    mise exec "node@$v" -- npm ls -g --depth=0 --parseable >"$PROBES/node-$v" 2>/dev/null &
  done
fi
if [ -f "$HOME/.default-gems" ]; then
  for v in $(versions_of ruby); do
    mise exec "ruby@$v" -- gem list --no-versions >"$PROBES/ruby-$v" 2>/dev/null &
  done
fi
wait

# node versions x ~/.default-npm-packages
if [ -f "$HOME/.default-npm-packages" ]; then
  for v in $(versions_of node); do
    while read -r pkg _; do
      [ -n "$pkg" ] || continue
      case "$pkg" in \#*) continue ;; esac
      if grep -q "/$pkg\$" "$PROBES/node-$v"; then
        :
      elif [ "$MODE" = "install" ]; then
        echo "installing $pkg for node $v"
        mise exec "node@$v" -- npm install -g "$pkg"
      else
        echo "missing: node $v npm $pkg"
        STATUS=1
      fi
    done <"$HOME/.default-npm-packages"
  done
fi

# ruby versions x ~/.default-gems
if [ -f "$HOME/.default-gems" ]; then
  for v in $(versions_of ruby); do
    while read -r pkg _; do
      [ -n "$pkg" ] || continue
      case "$pkg" in \#*) continue ;; esac
      if grep -qx "$pkg" "$PROBES/ruby-$v"; then
        :
      elif [ "$MODE" = "install" ]; then
        echo "installing $pkg for ruby $v"
        mise exec "ruby@$v" -- gem install "$pkg"
      else
        echo "missing: ruby $v gem $pkg"
        STATUS=1
      fi
    done <"$HOME/.default-gems"
  done
fi

exit $STATUS
