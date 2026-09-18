#!/bin/sh
# Custom `loadout outdated` oracle: is the claude binary itself behind the
# latest published Claude Code release? claude.ai/install.sh installs it as
# a plain self-updating binary (see manifest.d/install/cli-tools/claude.toml),
# so no package manager knows about it — same shape as the asdf oracle.
# `claude update` does the actual upgrade in place, so no re-install needed.
#
#   claude.sh                print `claude <current> <latest>` when behind, else nothing
#   claude.sh update claude  install the latest release over the current binary
#
# Silent when claude isn't installed or the network is down.
set -eu

current() {
  claude --version 2>/dev/null | sed -n 's/^\([0-9][0-9.]*\).*/\1/p'
}

latest() {
  curl -fsSL https://downloads.claude.ai/claude-code-releases/latest 2>/dev/null
}

case ${1:-} in
update)
  [ "${2:-}" = claude ] || { echo "usage: $0 update claude" >&2; exit 2; }
  claude update
  echo "claude $(current)"
  ;;
"")
  cur=$(current) || exit 0
  [ -n "$cur" ] || exit 0
  new=$(latest) || exit 0
  [ -n "$new" ] && [ "$new" != "$cur" ] && echo "claude $cur $new"
  exit 0
  ;;
*)
  echo "usage: $0 [update claude]" >&2
  exit 2
  ;;
esac
