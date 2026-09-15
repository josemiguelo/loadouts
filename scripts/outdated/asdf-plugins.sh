#!/bin/sh
# Custom `loadout outdated` oracle: are the asdf plugin pins in
# ~/.plugin-versions behind their GitHub repos? Prints one
# "<plugin> <pinned-sha> <remote-tip-sha> [note]" line per plugin whose pin
# is behind — the note is the commits-behind count when the local plugin
# clone can compute it. Silent when current, offline, or the file doesn't
# exist (oracle contract: only outdated items speak). Remotes probed in
# parallel.
#
# `update <plugin>` is the other half (loadout calls it per row): move that
# plugin's pin to its remote tip and refresh the installed plugin. One plugin
# per call — a pin is a line of its own, nothing is shared with the next.
set -eu

PINS="$HOME/.plugin-versions"
[ -f "$PINS" ] || exit 0

if [ "${1:-}" = "update" ]; then
  plugin=${2:?usage: asdf-plugins.sh update <plugin>}
  url=$(awk -v p="$plugin" '$1 == p { print $2 }' "$PINS")
  [ -n "$url" ] || { echo "no pin for '$plugin' in $PINS" >&2; exit 1; }
  tip=$(git ls-remote "$url" HEAD | awk '{print $1}')
  [ -n "$tip" ] || { echo "could not reach $url" >&2; exit 1; }

  # Rewrite that line only, keeping the file's column alignment.
  tmp=$(mktemp)
  awk -v p="$plugin" -v tip="$tip" '
    $1 == p { printf "%-41s %-57s %s\n", $1, $2, tip; next }
    { print }
  ' "$PINS" > "$tmp" && mv "$tmp" "$PINS"
  echo "$plugin pinned to $tip"

  # Bring the installed plugin in line with the new pin — adding it first
  # when it isn't here at all (a "not installed" row).
  if command -v asdf >/dev/null 2>&1; then
    [ -d "$HOME/.asdf/plugins/$plugin" ] || asdf plugin add "$plugin" "$url"
    asdf plugin update "$plugin"
  fi
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

while read -r plugin url pin _; do
  [ -n "$plugin" ] || continue
  case "$plugin" in \#*) continue ;; esac
  (
    # The config is the list: a pinned plugin with no clone is a row of its
    # own, before any question about its remote.
    # A GitHub URL in the pin file gives loadout a page to open (K).
    gh=$(printf '%s' "$url" | sed -n 's#^\(git@github\.com:\|https://github\.com/\)\([^/]*/[^/]*\)$#https://github.com/\2#p' | sed 's#\.git$##')
    if [ ! -d "$HOME/.asdf/plugins/$plugin/.git" ]; then
      printf '%s - %.9s not installed %s\n' "$plugin" "$pin" "$gh" > "$TMP/$plugin"
      exit 0
    fi
    tip=$(git ls-remote "$url" HEAD 2>/dev/null | awk '{print $1}')
    if [ -n "$tip" ] && [ "$tip" != "$pin" ]; then
      note=""
      dir="$HOME/.asdf/plugins/$plugin"
      if [ -d "$dir/.git" ]; then
        behind=$(git -C "$dir" fetch -q origin HEAD 2>/dev/null &&
          git -C "$dir" rev-list --count "$pin..FETCH_HEAD" 2>/dev/null) || behind=""
        [ -n "$behind" ] && note="$behind commit(s) behind"
      fi
      [ -n "$gh" ] && note="$note $gh/compare/$(printf %.9s "$pin")...$(printf %.9s "$tip")"
      printf '%s %.9s %.9s %s\n' "$plugin" "$pin" "$tip" "$note" > "$TMP/$plugin"
    fi
  ) &
done < "$PINS"
wait

cat "$TMP"/* 2>/dev/null || true
