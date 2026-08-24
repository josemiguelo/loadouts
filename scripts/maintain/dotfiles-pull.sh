#!/bin/sh
# Dotfiles REMOTE freshness: is the local chezmoi source behind its origin?
# Catches "edited dotfiles on machine A, machine B is stale". The check
# fetches at most every 6h (throttled on FETCH_HEAD's mtime) and fails soft
# offline, so `status` can afford it; converge is a pull only — applying the
# pulled target state is dotfiles-apply's job (order them in maintain).
# Modes: `check` / `install` (default).
set -eu

MODE="${1:-install}"
case "$MODE" in
check | install) ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac

# chezmoi owns the source location; don't hardcode it.
SOURCE=$(chezmoi source-path 2>/dev/null || true)
[ -n "$SOURCE" ] && [ -d "$SOURCE/.git" ] || { echo "missing: dotfiles not initialized"; exit 1; }

fetch_throttled() {
  if [ -z "$(find "$SOURCE/.git/FETCH_HEAD" -mmin -360 2>/dev/null)" ]; then
    git -C "$SOURCE" fetch -q 2>/dev/null || true # offline: keep last-known refs
  fi
}

if [ "$MODE" = "check" ]; then
  fetch_throttled
  behind=$(git -C "$SOURCE" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)
  if [ "$behind" -gt 0 ]; then
    echo "missing: dotfiles source is $behind commit(s) behind origin"
    exit 1
  fi
  exit 0
fi

# --ff-only: a diverged source (local commits) fails visibly instead of
# merging silently — resolve deliberately in the source dir.
chezmoi git -- fetch -q
chezmoi git -- pull -q --ff-only
echo "dotfiles source up to date with origin"
