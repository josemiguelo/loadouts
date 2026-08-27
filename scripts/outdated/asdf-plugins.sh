#!/bin/sh
# Custom `loadout outdated` oracle: are the asdf plugin pins in
# ~/.plugin-versions behind their GitHub repos? Prints one
# "<plugin> <pinned-sha> <remote-tip-sha> [note]" line per plugin whose pin
# is behind — the note is the commits-behind count when the local plugin
# clone can compute it. Silent when current, offline, or the file doesn't
# exist (oracle contract: only outdated items speak). Remotes probed in
# parallel.
set -eu

PINS="$HOME/.plugin-versions"
[ -f "$PINS" ] || exit 0

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

while read -r plugin url pin _; do
  [ -n "$plugin" ] || continue
  case "$plugin" in \#*) continue ;; esac
  (
    tip=$(git ls-remote "$url" HEAD 2>/dev/null | awk '{print $1}')
    if [ -n "$tip" ] && [ "$tip" != "$pin" ]; then
      note=""
      dir="$HOME/.asdf/plugins/$plugin"
      if [ -d "$dir/.git" ]; then
        behind=$(git -C "$dir" fetch -q origin HEAD 2>/dev/null &&
          git -C "$dir" rev-list --count "$pin..FETCH_HEAD" 2>/dev/null) || behind=""
        [ -n "$behind" ] && note="$behind commit(s) behind"
      fi
      printf '%s %.9s %.9s %s\n' "$plugin" "$pin" "$tip" "$note" > "$TMP/$plugin"
    fi
  ) &
done < "$PINS"
wait

cat "$TMP"/* 2>/dev/null || true
