#!/bin/sh
# Shared engine for clone-tracking oracles: each argument is a git clone
# expected to track its remote's default branch. Fetches all in parallel and
# prints "<name> <head-sha> <tip-sha> N commit(s) behind" for each clone
# whose HEAD is behind (a clone provably ahead-or-equal prints nothing) — name is derived per caller via GCB_NAME (a shell
# snippet evaluated with $dir set). Shallow clones still compare shas; the
# count is omitted when history can't provide it.
set -eu

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

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
      name=$(eval "$GCB_NAME")
      printf '%s %.9s %.9s %s\n' "$name" "$head" "$tip" "$note" > "$TMP/$i"
    fi
  ) &
done
wait

cat "$TMP"/* 2>/dev/null | sort || true
