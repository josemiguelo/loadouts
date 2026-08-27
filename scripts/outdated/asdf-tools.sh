#!/bin/sh
# Custom `loadout outdated` oracle: are the runtime pins in ~/.tool-versions
# behind upstream? Prints "<tool> <pin> <latest>" for each tool whose primary
# pin differs from `asdf latest`. Java is asked within its distro+major
# (adoptopenjdk-21) — the global latest is a different distro entirely.
# Moving targets (nightly) and tools asdf can't answer for stay silent.
set -eu

PINS="$HOME/.tool-versions"
[ -f "$PINS" ] && command -v asdf >/dev/null 2>&1 || exit 0

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
