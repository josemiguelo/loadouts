#!/bin/sh
# Where installed bar widgets (omarchy-plugins, omarchy-bar-icons) sit, from
# the machine's multi-line opt-in, one widget per line:
# "<id> <section> <before|after> <neighbour-id>"
# ("crmne.mpris left after tornikegomareli.spaces"). Placement is Omarchy's
# own bar layout (~/.config/omarchy/shell.json), changed with `omarchy bar
# move`. A widget with omarchy-bar/settings/<id>.json gets those settings set
# with `omarchy bar set` into its entry (keys the file doesn't list are left
# as they are). An id whose plugin has an enabled omarchy-bar-icons clone
# (clonedFrom) stands for the clone, which has taken its place. The check:
# each widget enabled, right before/after its neighbour in that section, and
# every listed setting at its value.
# usage: omarchy-bar-widgets.sh [check] "<id> <section> <before|after> <neighbour>"...
set -eu

MODE=install
if [ "${1:-}" = check ]; then MODE=check; shift; fi
[ $# -gt 0 ] || { echo "usage: $0 [check] \"<id> <section> <before|after> <neighbour>\"..." >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
JSON=$HOME/.config/omarchy/shell.json

enabled() {
  omarchy plugin list --json | jq -e --arg id "$1" 'any(.[]; .id == $id and .enabled)' >/dev/null
}

# The plugin's enabled clone, else the id itself.
effective() {
  omarchy plugin list --json | jq -r --arg id "$1" '[.[] | select(.enabled and .clonedFrom == $id) | .id][0] // $id'
}

# placed <id> <section> <before|after> <neighbour>
placed() {
  [ -f "$JSON" ] && jq -e --arg id "$1" --arg s "$2" --arg rel "$3" --arg n "$4" '
    [.bar.layout[$s][]?.id] as $ids
    | ($ids | index($id)) as $i | ($ids | index($n)) as $j
    | $i != null and $j != null and (if $rel == "before" then $i + 1 == $j else $i == $j + 1 end)' "$JSON" >/dev/null
}

# configured <id> <settings-id>: the settings file is named by the opt-in's id.
configured() {
  file=$HERE/omarchy-bar/settings/$2.json
  [ -f "$file" ] || return 0
  jq -e -n --arg id "$1" --slurpfile want "$file" --slurpfile shell "$JSON" '
    ([$shell[0].bar.layout[]?[]? | select(.id == $id)][0] // {}) as $entry
    | $want[0] | to_entries | all(.value == $entry[.key])' >/dev/null
}

configure() {
  file=$HERE/omarchy-bar/settings/$2.json
  for key in $(jq -r 'keys[]' "$file"); do
    omarchy bar set "$1" "$key" "$(jq -c --arg k "$key" '.[$k]' "$file")" --json >/dev/null
  done
}

# The arguments as one widget per line: loadout splits a multi-line opt-in
# on whitespace, so the words are regrouped in fours.
lines() {
  printf '%s\n' "$@" | tr -s ' \t' '\n\n' | awk 'NF { w[++n] = $0 }
    END { if (n % 4) { print "BAD"; exit } for (i = 1; i <= n; i += 4) print w[i], w[i+1], w[i+2], w[i+3] }'
}

[ "$(lines "$@" | head -1)" != BAD ] ||
  { echo "each widget needs four words: <id> <section> <before|after> <neighbour>" >&2; exit 2; }

failed=0
lines "$@" | {
  while read -r name section rel near; do
    case "$rel" in before | after) ;; *) echo "$name: <before|after>, not '$rel'" >&2; exit 2 ;; esac
    id=$(effective "$name")
    neighbour=$(effective "$near")
    if [ "$MODE" = install ]; then
      enabled "$id" || { echo "$id isn't installed and enabled" >&2; failed=1; continue; }
      placed "$id" "$section" "$rel" "$neighbour" ||
        omarchy bar move "$id" --section "$section" "--$rel" "$neighbour" >/dev/null
      configured "$id" "$name" || configure "$id" "$name"
    fi
    if ! { enabled "$id" && placed "$id" "$section" "$rel" "$neighbour" && configured "$id" "$name"; }; then
      [ "$MODE" = check ] || echo "$id isn't at $section, $rel $neighbour, with its settings after install" >&2
      failed=1
    fi
  done
  exit "$failed"
}
