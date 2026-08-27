#!/bin/sh
# Dotfiles OUTBOUND freshness: is this machine sitting on dotfiles changes
# the fleet can't see? The mirror of dotfiles-pull — pull watches what origin
# has that we don't, this watches what we have that origin doesn't:
# uncommitted edits in the chezmoi source, or committed-but-unpushed work.
# Check is local-only (no fetch, instant). Converge pushes when the source
# is clean and ahead; a dirty source fails visibly — writing the commit is a
# human decision, never automated. Modes: `check` / `install` (default).
set -eu

MODE="${1:-install}"
case "$MODE" in
check | install) ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac

# chezmoi owns the source location; don't hardcode it.
SOURCE=$(chezmoi source-path 2>/dev/null || true)
[ -n "$SOURCE" ] && [ -d "$SOURCE/.git" ] || { echo "missing: dotfiles not initialized"; exit 1; }

dirty=$(git -C "$SOURCE" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
ahead=$(git -C "$SOURCE" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)

if [ "$MODE" = "check" ]; then
  if [ "$dirty" -gt 0 ]; then
    echo "missing: $dirty uncommitted change(s) in the dotfiles source"
    exit 1
  fi
  if [ "$ahead" -gt 0 ]; then
    echo "missing: dotfiles source is $ahead commit(s) ahead of origin — push them"
    exit 1
  fi
  exit 0
fi

if [ "$dirty" -gt 0 ]; then
  echo "dotfiles source has $dirty uncommitted change(s) — commit them yourself:" >&2
  git -C "$SOURCE" status --short >&2
  exit 1
fi
if [ "$ahead" -gt 0 ]; then
  chezmoi git -- push -q
  echo "pushed $ahead commit(s) to origin"
else
  echo "nothing to push"
fi
