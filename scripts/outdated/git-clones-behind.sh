#!/bin/sh
# Shared engine for clone-tracking oracles: each argument is a git clone
# expected to track its remote's default branch. Fetches all in parallel and
# prints "<name> <head-sha> <tip-sha> N commit(s) behind" for each clone
# whose HEAD is behind (a clone provably ahead-or-equal prints nothing) — name is derived per caller via GCB_NAME (a shell
# snippet evaluated with $dir set). Shallow clones still compare shas; the
# count is omitted when history can't provide it. A GitHub origin adds the
# compare page for the two shas to the tail — loadout offers it under K.
#
# `update <name> <dir>...` is the other half (loadout calls it per row): fast
# -forward the ONE clone whose derived name matches, leaving the rest alone.
# A clone that can't fast-forward fails loudly rather than rewriting history.
set -eu

if [ "${1:-}" = "update" ]; then
  shift
  want=${1:?usage: git-clones-behind.sh update <name> <dir>...}
  shift
  for dir in "$@"; do
    [ -d "$dir/.git" ] || continue
    name=$(eval "$GCB_NAME")
    [ "$name" = "$want" ] || continue
    echo "updating $name ($dir)"
    git -C "$dir" pull --ff-only
    exit $?
  done
  echo "no clone named '$want' here" >&2
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# https://github.com/owner/repo for a GitHub origin (ssh or https), else nothing.
github_of() {
  git -C "$1" remote get-url origin 2>/dev/null \
    | sed -n 's#^\(git@github\.com:\|https://github\.com/\)\([^/]*/[^/]*\)$#https://github.com/\2#p' \
    | sed 's#\.git$##'
}

i=0
for dir in "$@"; do
  [ -d "$dir/.git" ] || continue
  i=$((i + 1))
  (
    head=$(git -C "$dir" rev-parse HEAD 2>/dev/null) || exit 0
    git -C "$dir" fetch -q origin HEAD 2>/dev/null || exit 0
    tip=$(git -C "$dir" rev-parse FETCH_HEAD 2>/dev/null) || exit 0
    if [ "$tip" != "$head" ]; then
      behind=$(git -C "$dir" rev-list --count "$head..FETCH_HEAD" 2>/dev/null) || behind=""
      # A sha mismatch with provably zero commits behind means ahead-or-equal
      # (e.g. a pin on a non-default branch) — not outdated, no row.
      if [ "$behind" = "0" ]; then exit 0; fi
      note=""
      [ -n "$behind" ] && note="$behind commit(s) behind"
      gh=$(github_of "$dir")
      [ -n "$gh" ] && note="$note $gh/compare/$(printf %.9s "$head")...$(printf %.9s "$tip")"
      name=$(eval "$GCB_NAME")
      printf '%s %.9s %.9s %s\n' "$name" "$head" "$tip" "$note" > "$TMP/$i"
    fi
  ) &
done
wait

cat "$TMP"/* 2>/dev/null | sort || true
