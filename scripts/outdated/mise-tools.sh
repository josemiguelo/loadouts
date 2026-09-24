#!/bin/sh
# Custom `loadout outdated` oracle: are the pins in ~/.config/mise/config.toml
# behind upstream WITHIN THEIR MAJOR? Same rules as asdf-tools.sh: only each
# tool's primary (first) pin, compared against its own major line — ruby
# 3.4.8 against 3.x, never 4.x; java's "major" is its vendor+major
# (temurin-21). Crossing a major is a decision, not an update. Moving targets
# (latest, nightly, stable) stay silent — `omarchy update` / `mise up` move
# the "latest" ones.
#
# `update <tool>` is the other half (loadout calls it per row): install the
# newest version on that line and make it the primary pin, leaving the older
# versions listed. The pin is rewritten in place, not with `mise config set`,
# which drops the comment above the key. The file is the dotfiles' — re-add it
# afterwards (dotfiles-apply says so).
set -eu
command -v mise >/dev/null 2>&1 || exit 0
CFG="${MISE_GLOBAL_CONFIG_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml}"
[ -f "$CFG" ] || exit 0
cd "$HOME"

# "<tool> <primary pin>" per [tools] entry, in file order; stops at the first
# table (a tool with options, e.g. cocoapods = { os = ... }).
pins() {
  mise config get -f "$CFG" tools 2>/dev/null |
    sed -n '/^\[/q; s/^"\{0,1\}\([^"= ]*\)"\{0,1\} = \[\{0,1\}"\([^"]*\)".*/\1 \2/p'
}

# Latest stable version on the pin's major line: everything before the first
# dot is the "major", matched ANCHORED against mise's full list (a prefix
# query would take tomcat 9 to 10.x). Pre-releases dropped, version-sorted.
latest_in_major() {
  major=${2%%.*}
  mise ls-remote "$1" 2>/dev/null \
    | grep -E "^$(printf '%s' "$major" | sed 's/[.+]/\\&/g')\." \
    | grep -iv -E '(-src|-dev|-latest|-stm|[-.]rc|-milestone|-alpha|-beta|[-.]pre|-next|(a|b|c)[0-9]+|snapshot|master|nightly)' \
    | sort -V \
    | tail -1
}

if [ "${1:-}" = "update" ]; then
  tool=${2:?usage: mise-tools.sh update <tool>}
  pin=$(pins | awk -v t="$tool" '$1 == t { print $2 }')
  [ -n "$pin" ] || { echo "no pin for '$tool' in $CFG" >&2; exit 1; }
  latest=$(latest_in_major "$tool" "$pin")
  [ -n "$latest" ] || { echo "mise lists nothing on ${pin%%.*}.x for '$tool'" >&2; exit 1; }
  if [ "$latest" = "$pin" ]; then
    echo "$tool already pinned to $latest"
    exit 0
  fi
  mise install "$tool@$latest"
  # Swap the first "<pin>" on the tool's own line; everything else stays.
  tmp=$(mktemp)
  awk -v t="$tool" -v old="\"$pin\"" -v new="\"$latest\"" '
    !done && ($1 == t || $1 == "\"" t "\"") && $2 == "=" {
      i = index($0, old)
      if (i) { $0 = substr($0, 1, i - 1) new substr($0, i + length(old)); done = 1 }
    }
    { print }' "$CFG" >"$tmp"
  cat "$tmp" >"$CFG"
  rm -f "$tmp"
  echo "$tool pinned to $latest (was $pin)"
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# From a file, not a pipe: the loop must run in THIS shell so `wait` sees its
# background jobs.
pins >"$TMP/.pins"
while read -r tool pin; do
  case "$pin" in latest|nightly|stable|lts|system|ref:*|"") continue ;; esac
  (
    latest=$(latest_in_major "$tool" "$pin")
    if [ -n "${latest:-}" ] && [ "$latest" != "$pin" ]; then
      printf '%s %s %s\n' "$tool" "$pin" "$latest" >"$TMP/$(printf '%s' "$tool" | tr '/:' '__')"
    fi
  ) &
done <"$TMP/.pins"
wait
cat "$TMP"/* 2>/dev/null || true
