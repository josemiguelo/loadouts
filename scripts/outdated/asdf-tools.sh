#!/bin/sh
# Custom `loadout outdated` oracle: are the runtime pins in ~/.tool-versions
# behind upstream WITHIN THEIR MAJOR? Prints "<tool> <pin> <latest>" for each
# tool whose primary pin has a newer version on the same major line: ruby
# 3.4.8 is compared against 3.x, never 4.x; java's "major" is its distro+major
# (adoptopenjdk-21). Crossing a major is a decision, not an update.
# Moving targets (nightly) and tools asdf can't answer for stay silent.
#
# `update <tool>` is the other half (loadout calls it per row): install the
# latest version asdf offers for that tool and make it the home pin, leaving
# the older versions installed (this file keeps fallbacks after the primary).
set -eu

PINS="$HOME/.tool-versions"
[ -f "$PINS" ] && command -v asdf >/dev/null 2>&1 || exit 0

# Latest stable version on the pin's major line. Everything before the first
# dot is the "major" (3 for ruby 3.4.8, adoptopenjdk-21 for java), matched
# ANCHORED against the plugin's full list. Not `asdf latest <filter>`: that is
# a substring match some plugins ignore (tomcat 9 -> 10.1.59). Pre-releases
# are dropped with the same pattern asdf itself uses, and the survivors are
# version-sorted — a plugin's own order can be lexical (maven listed 3.9.9
# after 3.9.16).
latest_in_major() {
  major=${2%%.*}
  asdf list all "$1" 2>/dev/null \
    | sed 's/^[[:space:]]*//' \
    | grep -E "^$(printf '%s' "$major" | sed 's/[.+]/\\&/g')\." \
    | grep -iv -E '(-src|-dev|-latest|-stm|[-.]rc|-milestone|-alpha|-beta|[-.]pre|-next|(a|b|c)[0-9]+|snapshot|master)' \
    | sort -V \
    | tail -1
}

if [ "${1:-}" = "update" ]; then
  tool=${2:?usage: asdf-tools.sh update <tool>}
  pin=$(awk -v t="$tool" '$1 == t { print $2 }' "$PINS")
  [ -n "$pin" ] || { echo "no pin for '$tool' in $PINS" >&2; exit 1; }
  latest=$(latest_in_major "$tool" "$pin")
  [ -n "$latest" ] || { echo "asdf lists nothing on ${pin%%.*}.x for '$tool'" >&2; exit 1; }
  if [ "$latest" = "$pin" ]; then
    echo "$tool already pinned to $latest"
    exit 0
  fi
  asdf install "$tool" "$latest"
  # Keep the fallback versions that follow the primary pin on that line.
  rest=$(awk -v t="$tool" '$1 == t { $1=""; $2=""; sub(/^  */, ""); print }' "$PINS")
  asdf set --home "$tool" "$latest" $rest
  echo "$tool pinned to $latest (was $pin)"
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

while read -r tool pin _; do
  [ -n "$tool" ] || continue
  case "$tool" in \#*) continue ;; esac
  case "$pin" in nightly|latest|system|"") continue ;; esac
  (
    latest=$(latest_in_major "$tool" "$pin")
    if [ -n "${latest:-}" ] && [ "$latest" != "$pin" ]; then
      printf '%s %s %s\n' "$tool" "$pin" "$latest" > "$TMP/$tool"
    fi
  ) &
done < "$PINS"
wait

cat "$TMP"/* 2>/dev/null || true
