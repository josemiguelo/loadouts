#!/bin/sh
# tmux plugins, exactly the `set -g @plugin` lines in tmux.conf declare (the
# file comes from the chezmoi dotfiles). tpack keeps no lockfile, so the
# check is presence: EVERY declared plugin has a clone. Whether a clone is
# behind its remote is the tmux-plugins oracle's question, not this one's.
# Modes: `check` / `install` (default).
set -eu
export PATH="$HOME/.local/bin:/home/linuxbrew/.linuxbrew/bin:/opt/homebrew/bin:$PATH"

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
# Same dirs the tmux-plugins oracle walks (scripts/outdated/tmux-plugins.sh).
CLONES="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/plugins"

# One "<owner/repo>" per declared plugin, comments dropped.
declared() {
  [ -f "$CONF" ] || return 0
  sed -n "s/^[[:space:]]*set[[:space:]]*-g[[:space:]]*@plugin[[:space:]]*['\"]\([^'\"#]*\).*/\1/p" "$CONF"
}

check() {
  [ -f "$CONF" ] || { echo "tmux.conf not found" >&2; exit 1; }
  status=0
  for repo in $(declared); do
    name=${repo##*/}
    # tpack names the clone <repo>-<12-hex-hash>.
    found=0
    for dir in "$CLONES/$name"-*/; do
      [ -d "$dir/.git" ] && { found=1; break; }
    done
    if [ "$found" = 0 ]; then
      echo "missing plugin: $repo"
      status=1
    fi
  done
  exit $status
}

install_all() {
  command -v tpack >/dev/null 2>&1 || { echo "tpack not found" >&2; exit 1; }
  tpack install
}

case "${1:-install}" in
check) check ;;
install) install_all ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
