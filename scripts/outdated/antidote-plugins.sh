#!/bin/sh
# Custom `loadout outdated` oracle for the antidote bundles $ZDOTDIR/.zplugins
# declares (the file comes from the chezmoi dotfiles; local $ZDOTDIR/...
# entries are dotfiles, not clones). The config is the list, not the clone
# dirs: a declared bundle with no clone is a row ("not installed", candidate
# = its remote tip), an installed one is a row when its clone is behind its
# remote tip. antidote itself is a separate oracle. Silent when zsh isn't
# set up on this machine.
#
# `update <owner/repo>` (loadout calls it per row): clone what's missing
# with `antidote bundle`, fast-forward the one clone that's behind.
set -eu

ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"
BUNDLES="$ZDOTDIR/.zplugins"
ANTIDOTE="${XDG_DATA_HOME:-$HOME/.local/share}/mattmc3/antidote"
CLONES="${XDG_CACHE_HOME:-$HOME/.cache}/antidote"
GCB="$(dirname "$0")/git-clones-behind.sh"
# name = owner/repo, the last two path segments of the clone dir
export GCB_NAME='printf "%s/%s" "$(basename "$(dirname "$dir")")" "$(basename "$dir")"'

[ -f "$BUNDLES" ] || exit 0

declared() {
  sed -n 's/^[[:space:]]*\([A-Za-z0-9_.-]*\/[A-Za-z0-9_.-]*\)\([[:space:]].*\)\{0,1\}$/\1/p' "$BUNDLES" | sort -u
}

if [ "${1:-}" = "update" ]; then
  want=${2:?usage: antidote-plugins.sh update <owner/repo>}
  if [ -d "$CLONES/$want/.git" ]; then
    exec sh "$GCB" update "$want" "$CLONES/$want/"
  fi
  declared | grep -qx "$want" || { echo ".zplugins declares no bundle '$want'" >&2; exit 1; }
  echo "installing $want"
  exec zsh -c "source '$ANTIDOTE/antidote.zsh' && antidote bundle < '$BUNDLES' > /dev/null"
fi

dirs=""
for repo in $(declared); do
  if [ -d "$CLONES/$repo/.git" ]; then
    dirs="$dirs $CLONES/$repo/"
  else
    tip=$(git ls-remote "https://github.com/$repo" HEAD 2>/dev/null | cut -c1-9)
    printf '%s - %s not installed https://github.com/%s\n' "$repo" "${tip:-?}" "$repo"
  fi
done
# shellcheck disable=SC2086
[ -z "$dirs" ] || exec sh "$GCB" $dirs
