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
# Same clones the antidote / antidote-plugins oracles walk (scripts/outdated/),
# and found the same way: ask antidote, never guess. The XDG path is only
# Linux's default — on macOS antidote clones into ~/Library/Caches/antidote,
# so guessing called every installed bundle missing and left this script
# permanently pending: `antidote bundle` had nothing to do, and the check
# still failed after it ran.
ANTIDOTE="${XDG_DATA_HOME:-$HOME/.local/share}/mattmc3/antidote"
CLONES="${ANTIDOTE_HOME:-}"
[ -n "$CLONES" ] || CLONES=$(zsh -fc "source '$ANTIDOTE/antidote.zsh' && antidote home" 2>/dev/null)
[ -n "$CLONES" ] || { echo "cannot ask antidote where it clones: $ANTIDOTE/antidote.zsh" >&2; exit 1; }

# One "<owner/repo>" per remote bundle, comments and local entries dropped.
declared() {
  [ -f "$BUNDLES" ] || return 0
  sed -n 's/^[[:space:]]*\([A-Za-z0-9_.-]*\/[A-Za-z0-9_.-]*\)\([[:space:]].*\)\{0,1\}$/\1/p' "$BUNDLES" | sort -u
}

check() {
  [ -f "$BUNDLES" ] || { echo ".zplugins not found" >&2; exit 1; }
  status=0
  [ -d "$ANTIDOTE/.git" ] || { echo "missing: antidote itself ($ANTIDOTE)"; status=1; }
  for repo in $(declared); do
    [ -d "$CLONES/$repo/.git" ] || { echo "missing bundle: $repo"; status=1; }
  done
  exit $status
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
