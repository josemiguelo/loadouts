#!/bin/sh
# Custom `loadout outdated` oracle for the tmux plugins tmux.conf declares
# (`set -g @plugin 'owner/repo'`; the file comes from the chezmoi dotfiles).
# The config is the list, not the clone dirs: a declared plugin with no
# clone is a row ("not installed", candidate = its remote tip), an installed
# one is a row when its clone is behind its remote tip. Silent when tmux
# isn't set up on this machine.
#
# `update <name>` (loadout calls it per row): clone what's missing with
# `tpack install`, fast-forward the one clone that's behind.
set -eu
export PATH="$HOME/.local/bin:/home/linuxbrew/.linuxbrew/bin:/opt/homebrew/bin:$PATH"

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
CLONES="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/plugins"
GCB="$(dirname "$0")/git-clones-behind.sh"
# tpack names the clone <repo>-<12-hex-hash>; the row is named <repo>.
export GCB_NAME='basename "$dir" | sed "s/-[0-9a-f]\{12\}$//"'

[ -f "$CONF" ] || exit 0

declared() {
  sed -n "s/^[[:space:]]*set[[:space:]]*-g[[:space:]]*@plugin[[:space:]]*['\"]\([^'\"#]*\).*/\1/p" "$CONF"
}

clone_of() {
  for dir in "$CLONES/${1##*/}"-*/; do
    [ -d "$dir/.git" ] && { printf '%s\n' "$dir"; return 0; }
  done
  return 1
}

if [ "${1:-}" = "update" ]; then
  want=${2:?usage: tmux-plugins.sh update <name>}
  for repo in $(declared); do
    [ "${repo##*/}" = "$want" ] || continue
    if dir=$(clone_of "$repo"); then
      exec sh "$GCB" update "$want" "$dir"
    fi
    echo "installing $repo"
    exec tpack install
  done
  echo "tmux.conf declares no plugin named '$want'" >&2
  exit 1
fi

dirs=""
for repo in $(declared); do
  if dir=$(clone_of "$repo"); then
    dirs="$dirs $dir"
  else
    tip=$(git ls-remote "https://github.com/$repo" HEAD 2>/dev/null | cut -c1-9)
    printf '%s - %s not installed https://github.com/%s\n' "${repo##*/}" "${tip:-?}" "$repo"
  fi
done
# shellcheck disable=SC2086
[ -z "$dirs" ] || exec sh "$GCB" $dirs
