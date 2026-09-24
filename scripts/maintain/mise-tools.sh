#!/bin/sh
# mise tools: every version ~/.config/mise/config.toml pins (the file comes
# from the chezmoi dotfiles; the mise-tools oracle moves its pins) is
# installed. The mise counterpart of asdf-tools.sh — no plugin step, mise
# resolves every tool from its own registry.
# Modes: `check` / `install` (default).
set -eu
command -v mise >/dev/null 2>&1 || { echo "mise not found" >&2; exit 1; }
# The global config only: from the repo's cwd mise would also look for
# project configs in its parents.
cd "$HOME"

case "${1:-install}" in
check)
  missing=$(mise ls --missing 2>/dev/null | awk '{ print $1 "@" $2 }')
  [ -z "$missing" ] && exit 0
  for m in $missing; do echo "missing: $m"; done
  exit 1
  ;;
install)
  mise install
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
