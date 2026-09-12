#!/bin/sh
# Custom `loadout outdated` oracle: are the runtime pins in ~/.tool-versions
# behind upstream? Prints "<tool> <pin> <latest>" for each tool whose primary
# pin differs from `asdf latest`. Java is asked within its distro+major
# (adoptopenjdk-21) — the global latest is a different distro entirely.
# Moving targets (nightly) and tools asdf can't answer for stay silent.
#
# `update <tool>` is the other half (loadout calls it per row): install the
# latest version asdf offers for that tool and make it the home pin, leaving
# the older versions installed (this file keeps fallbacks after the primary).
set -eu

PINS="$HOME/.tool-versions"
[ -f "$PINS" ] && command -v asdf >/dev/null 2>&1 || exit 0

if [ "${1:-}" = "update" ]; then
  tool=${2:?usage: asdf-tools.sh update <tool>}
  pin=$(awk -v t="$tool" '$1 == t { print $2 }' "$PINS")
  [ -n "$pin" ] || { echo "no pin for '$tool' in $PINS" >&2; exit 1; }
  case "$tool" in
    # Java's "latest" is a different distro entirely; stay inside this one.
    java) latest=$(asdf latest java "${pin%%.*}") ;;
    *) latest=$(asdf latest "$tool") ;;
  esac
  [ -n "$latest" ] || { echo "asdf has no latest for '$tool'" >&2; exit 1; }
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
    case "$tool" in
      java) latest=$(asdf latest java "${pin%%.*}" 2>/dev/null) ;;
      *) latest=$(asdf latest "$tool" 2>/dev/null) ;;
    esac
    if [ -n "${latest:-}" ] && [ "$latest" != "$pin" ]; then
      printf '%s %s %s\n' "$tool" "$pin" "$latest" > "$TMP/$tool"
    fi
  ) &
done < "$PINS"
wait

cat "$TMP"/* 2>/dev/null || true
