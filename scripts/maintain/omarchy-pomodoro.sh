#!/bin/sh
# The Pomodoro timer plugin (pomodoro-omarchy, installed by omarchy-plugins):
# on the bar's center section right after the clock, its settings from
# omarchy-pomodoro/settings.json (set with `omarchy bar set` into its
# shell.json entry; keys the file doesn't list are left as they are), and a
# Pomodoro submenu under Trigger in the Omarchy menu (Keystroke serves it):
# omarchy-pomodoro/menu.jsonc, kept as a block right after the opening brace
# of ~/.config/omarchy/extensions/omarchy-menu.jsonc. Its entries end in
# commas; the menu's reader drops trailing ones. They run the plugin's own
# bin/omarchy-pomodoro by its path, so nothing goes on the PATH. The widget
# placed and configured is the plugin's, or its omarchy-bar-icons clone
# (clonedFrom pomodoro-omarchy) once that has taken its place.
# Modes: `check` / `install` (default).
set -eu

ID=pomodoro-omarchy
AFTER=omarchy.clock
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC=$HERE/omarchy-pomodoro
JSON=$HOME/.config/omarchy/shell.json
MENU=$HOME/.config/omarchy/extensions/omarchy-menu.jsonc
BEGIN="  // >>> Managed by loadout (omarchy-pomodoro)"
END="  // <<< Managed by loadout (omarchy-pomodoro)"

enabled() {
  omarchy plugin list --json | jq -e --arg id "$1" 'any(.[]; .id == $id and .enabled)' >/dev/null
}

# The plugin's enabled clone, else the plugin.
WIDGET=$(omarchy plugin list --json | jq -r --arg id "$ID" '[.[] | select(.enabled and .clonedFrom == $id) | .id][0] // $id')

# In the center section, right after the clock.
placed() {
  [ -f "$JSON" ] && jq -e --arg id "$WIDGET" --arg after "$AFTER" '
    [.bar.layout.center[]?.id] as $c
    | ($c | index($after)) as $a | $a != null and $c[$a + 1] == $id' "$JSON" >/dev/null
}

configured() {
  jq -e -n --arg id "$WIDGET" --slurpfile want "$SRC/settings.json" --slurpfile shell "$JSON" '
    ([$shell[0].bar.layout[]?[]? | select(.id == $id)][0] // {}) as $entry
    | $want[0] | to_entries | all(.value == $entry[.key])' >/dev/null
}

block() {
  echo "$BEGIN"
  echo "  // Pomodoro under Trigger (scripts/maintain/omarchy-pomodoro.sh rewrites this block)."
  cat "$SRC/menu.jsonc"
  echo "$END"
}

current() {
  [ -f "$MENU" ] || return 0
  awk -v b="$BEGIN" -v e="$END" '$0 == b { keep = 1 } keep { print } $0 == e { keep = 0 }' "$MENU"
}

in_place() {
  enabled "$WIDGET" && placed && configured && [ "$(current)" = "$(block)" ]
}

case "${1:-install}" in
check)
  in_place
  ;;
install)
  enabled "$WIDGET" || { echo "$ID isn't installed and enabled: add it to omarchy-plugins" >&2; exit 1; }
  placed || omarchy bar move "$WIDGET" --section center --after "$AFTER" >/dev/null
  if ! configured; then
    for key in $(jq -r 'keys[]' "$SRC/settings.json"); do
      omarchy bar set "$WIDGET" "$key" "$(jq -c --arg k "$key" '.[$k]' "$SRC/settings.json")" --json >/dev/null
    done
  fi
  mkdir -p "$(dirname "$MENU")"
  [ -f "$MENU" ] || printf '{\n}\n' > "$MENU"
  grep -q '^[[:space:]]*{' "$MENU" || { echo "$MENU has no opening brace to put the menu entries after" >&2; exit 1; }
  # The file without the old block, the block right after the first line
  # that opens the object.
  rest=$(awk -v b="$BEGIN" -v e="$END" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' "$MENU")
  {
    printf '%s\n' "$rest" | awk '/^[[:space:]]*\{/ { print; exit } { print }'
    block
    printf '%s\n' "$rest" | awk 'found { print } !found && /^[[:space:]]*\{/ { found = 1 }'
  } > "$MENU.tmp"
  mv "$MENU.tmp" "$MENU"
  in_place || { echo "the Pomodoro plugin isn't placed, configured and in the menu after install" >&2; exit 1; }
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
