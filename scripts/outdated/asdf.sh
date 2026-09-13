#!/bin/sh
# Custom `loadout outdated` oracle: is the asdf binary itself behind its
# latest GitHub release? asdf is installed as a plain binary (see
# scripts/install/install-asdf.sh), so no package manager knows about it —
# this is the same shape as loadout's own self-check. Plugins and tool pins
# are separate oracles (asdf-plugins, asdf-tools).
#
#   asdf.sh              print `asdf <current> <latest>` when behind, else nothing
#   asdf.sh update asdf  install the latest release over the current binary
#
# Tags come from `git ls-remote`, not the GitHub API, so there's no rate
# limit to trip. Silent when asdf isn't installed or the network is down.
set -eu

current() {
  asdf --version 2>/dev/null | sed -n 's/.*v\([0-9][0-9.]*\).*/\1/p'
}

latest() {
  git ls-remote --tags --refs https://github.com/asdf-vm/asdf 'v[0-9]*' 2>/dev/null \
    | sed -n 's#.*refs/tags/v\([0-9][0-9.]*\)$#\1#p' \
    | sort -V | tail -1
}

case ${1:-} in
update)
  [ "${2:-}" = asdf ] || { echo "usage: $0 update asdf" >&2; exit 2; }
  new=$(latest)
  [ -n "$new" ] || { echo "could not resolve the latest asdf release" >&2; exit 1; }
  sh "$(dirname "$0")/../install/install-asdf.sh" "$new"
  echo "asdf $(current)"
  ;;
"")
  cur=$(current) || exit 0
  [ -n "$cur" ] || exit 0
  new=$(latest) || exit 0
  [ -n "$new" ] && [ "$new" != "$cur" ] && echo "asdf $cur $new"
  exit 0
  ;;
*)
  echo "usage: $0 [update asdf]" >&2
  exit 2
  ;;
esac
