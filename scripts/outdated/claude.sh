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
# Silent when claude isn't installed or the network is down — and when the
# claude here isn't the native install: on Omarchy mise owns it (the dotfiles'
# mise config, updated by `omarchy update`), and ~/.local/bin/claude is
# Omarchy's wrapper script, not the binary, so `claude update` would fight
# mise. The native installer's layout is the tell: ~/.local/bin/claude is a
# symlink into ~/.local/share/claude/.
set -eu

NATIVE="$HOME/.local/bin/claude"

current() {
  case "$(readlink "$NATIVE" 2>/dev/null)" in
    "$HOME/.local/share/claude/"*) ;;
    *) return 0 ;;
  esac
  "$NATIVE" --version 2>/dev/null | sed -n 's/^\([0-9][0-9.]*\).*/\1/p'
}

latest() {
  curl -fsSL https://downloads.claude.ai/claude-code-releases/latest 2>/dev/null
}

case ${1:-} in
update)
  [ "${2:-}" = claude ] || { echo "usage: $0 update claude" >&2; exit 2; }
  "$NATIVE" update
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
