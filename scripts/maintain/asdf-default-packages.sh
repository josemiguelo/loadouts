#!/bin/sh
# Default packages (asdf's ~/.default-npm-packages and ~/.default-gems)
# present in EVERY matching tool version from ~/.tool-versions. asdf only
# auto-installs them into newly built versions, so packages added later need
# this backfill into the versions that already exist.
# Modes: `check` / `install` (default).
# One `npm ls` / `gem list` query per tool version (not per package) — the
# per-package form made the check take minutes.
set -eu
export PATH="$HOME/.local/bin:$PATH"

TOOL_VERSIONS="$HOME/.tool-versions"
MODE="${1:-install}"
case "$MODE" in
check | install) ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
STATUS=0

versions_of() { awk -v p="$1" '$1 == p { $1 = ""; print }' "$TOOL_VERSIONS" 2>/dev/null; }

# nodejs versions x ~/.default-npm-packages
if [ -f "$HOME/.default-npm-packages" ]; then
  for v in $(versions_of nodejs); do
    globals=$(ASDF_NODEJS_VERSION="$v" npm ls -g --depth=0 --parseable 2>/dev/null || true)
    while read -r pkg _; do
      [ -n "$pkg" ] || continue
      case "$pkg" in \#*) continue ;; esac
      if printf '%s\n' "$globals" | grep -q "/$pkg\$"; then
        :
      elif [ "$MODE" = "install" ]; then
        echo "installing $pkg for nodejs $v"
        ASDF_NODEJS_VERSION="$v" npm install -g "$pkg"
      else
        echo "missing: nodejs $v npm $pkg"
        STATUS=1
      fi
    done <"$HOME/.default-npm-packages"
  done
fi

# ruby versions x ~/.default-gems
if [ -f "$HOME/.default-gems" ]; then
  for v in $(versions_of ruby); do
    gems=$(ASDF_RUBY_VERSION="$v" gem list --no-versions 2>/dev/null || true)
    while read -r pkg _; do
      [ -n "$pkg" ] || continue
      case "$pkg" in \#*) continue ;; esac
      if printf '%s\n' "$gems" | grep -qx "$pkg"; then
        :
      elif [ "$MODE" = "install" ]; then
        echo "installing $pkg for ruby $v"
        ASDF_RUBY_VERSION="$v" gem install "$pkg"
      else
        echo "missing: ruby $v gem $pkg"
        STATUS=1
      fi
    done <"$HOME/.default-gems"
  done
fi

exit $STATUS
