#!/bin/sh
# antidote and its bundles, exactly as $ZDOTDIR/.zplugins declares them (the
# file comes from the chezmoi dotfiles). antidote keeps no lockfile, so the
# check is presence: antidote itself is cloned, and EVERY owner/repo bundle
# has a clone. Local $ZDOTDIR/... entries are dotfiles, not clones — they
# are dotfiles-apply's business. Whether a clone is behind its remote is
# the antidote / antidote-plugins oracles' question, not this one's.
# Modes: `check` / `install` (default).
set -eu

ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"
BUNDLES="$ZDOTDIR/.zplugins"
ANTIDOTE="${XDG_DATA_HOME:-$HOME/.local/share}/mattmc3/antidote"

# "<owner/repo> <clone dir>" per declared bundle, "-" for one not cloned. The
# same clones the antidote-plugins oracle walks, found the same way: ask
# antidote (`antidote path`), never guess. Its home differs per OS (macOS:
# ~/Library/Caches/antidote) and its layout per version (2.x nests clones
# under github.com/), and each guess once left this check pending forever
# with every bundle in place. Needs antidote itself — callers check first.
bundle_paths() {
  # shellcheck disable=SC2046
  ANTIDOTE="$ANTIDOTE" zsh -fc '
    source "$ANTIDOTE/antidote.zsh" || exit 1
    for r in "$@"; do
      p=$(antidote path "$r" 2>/dev/null) && print -r -- "$r $p" || print -r -- "$r -"
    done' zsh $(declared)
}

# One "<owner/repo>" per remote bundle, comments and local entries dropped.
declared() {
  [ -f "$BUNDLES" ] || return 0
  sed -n 's/^[[:space:]]*\([A-Za-z0-9_.-]*\/[A-Za-z0-9_.-]*\)\([[:space:]].*\)\{0,1\}$/\1/p' "$BUNDLES" | sort -u
}

check() {
  [ -f "$BUNDLES" ] || { echo ".zplugins not found" >&2; exit 1; }
  # Without antidote there's nothing to ask about its bundles.
  [ -d "$ANTIDOTE/.git" ] || { echo "missing: antidote itself ($ANTIDOTE)"; exit 1; }
  missing=$(bundle_paths | awk '$2 == "-" { print $1 }')
  [ -z "$missing" ] && exit 0
  for repo in $missing; do echo "missing bundle: $repo"; done
  exit 1
}

install_all() {
  command -v zsh >/dev/null 2>&1 || { echo "zsh not found" >&2; exit 1; }
  [ -d "$ANTIDOTE/.git" ] || git clone --depth 1 --quiet https://github.com/mattmc3/antidote "$ANTIDOTE"
  # `antidote bundle` clones what's missing; the generated script is discarded
  # — the interactive shell regenerates its own on next start.
  zsh -c "source '$ANTIDOTE/antidote.zsh' && antidote bundle < '$BUNDLES' > /dev/null"
}

case "${1:-install}" in
check) check ;;
install) install_all ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
