#!/bin/sh
# The Omarchy bar's position, thickness and, optionally, the widget that
# replaces the stock workspace numbers, from the machine's opt-in
# ("omarchy-bar bottom 30 tornikegomareli.spaces").
#
# The position is Omarchy's own setting (~/.config/omarchy/shell.json,
# bar.position), set with `omarchy bar position`. The thickness is
# size-horizontal (top and bottom bars; size-vertical for left and right
# ones; Omarchy's default is 26) at font base-size 12, scaled with the font
# like Omarchy's; it lives in a block in ~/.config/omarchy/shell.toml, the
# machine-level file whose keys win over the theme's and which the shell
# reloads live. `omarchy display text size` edits [font] there and leaves the
# rest. A [bar] table outside the block would make the file invalid TOML, so
# install refuses one. The bar's text (clock, workspace numbers) has no size
# of its own: it is the shell's body text, [font] base-size.
#
# The workspace widget (a plugin omarchy-plugins installs) takes the stock
# omarchy.workspaces' place: moved right after it while it is on the bar,
# then the stock one is disabled. The widget's settings, when
# omarchy-bar/settings/<id>.json lists them, are set with `omarchy bar set`
# into its shell.json entry (keys the file doesn't list are left as they
# are); the check compares every listed key.
# usage: omarchy-bar.sh [check] <top|bottom|left|right> <size> [workspace-widget-id]
set -eu

USAGE="usage: $0 [check] <top|bottom|left|right> <size> [workspace-widget-id]"
MODE=install
if [ "${1:-}" = check ]; then MODE=check; shift; fi
POSITION=${1:?$USAGE}
SIZE=${2:?$USAGE}
WIDGET=${3:-}
case "$POSITION" in top | bottom) KEY=size-horizontal ;; left | right) KEY=size-vertical ;;
  *) echo "position must be top, bottom, left or right" >&2; exit 2 ;; esac
case "$SIZE" in '' | *[!0-9]*) echo "size must be a whole number" >&2; exit 2 ;; esac

STOCK=omarchy.workspaces
HERE="$(cd "$(dirname "$0")" && pwd)"
WIDGET_SETTINGS=$HERE/omarchy-bar/settings/$WIDGET.json
JSON=$HOME/.config/omarchy/shell.json
TOML=$HOME/.config/omarchy/shell.toml
BEGIN="# >>> Managed by loadout (omarchy-bar)"
END="# <<< Managed by loadout (omarchy-bar)"

block() {
  echo "$BEGIN"
  echo "# The bar's thickness at font base-size 12 (scripts/maintain/omarchy-bar.sh)."
  echo "[bar]"
  echo "$KEY = $SIZE"
  echo "$END"
}

current() {
  [ -f "$TOML" ] || return 0
  awk -v b="$BEGIN" -v e="$END" '$0 == b { keep = 1 } keep { print } $0 == e { keep = 0 }' "$TOML"
}

# shell.toml without the block.
rest() {
  [ -f "$TOML" ] || return 0
  awk -v b="$BEGIN" -v e="$END" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' "$TOML"
}

positioned() {
  [ -f "$JSON" ] && [ "$(jq -r '.bar.position // "top"' "$JSON")" = "$POSITION" ]
}

sized() {
  [ "$(current)" = "$(block)" ] && ! rest | grep -q '^[[:space:]]*\[bar\]'
}

enabled() {
  omarchy plugin list --json | jq -e --arg id "$1" 'any(.[]; .id == $id and .enabled)' >/dev/null
}

on_bar() {
  [ -f "$JSON" ] && jq -e --arg id "$1" '[.bar.layout[]?[]?.id] | index($id) != null' "$JSON" >/dev/null
}

# No widget named, or it's on the bar and the stock one is off.
replaced() {
  [ -z "$WIDGET" ] || { enabled "$WIDGET" && on_bar "$WIDGET" && ! enabled "$STOCK"; }
}

# Every key the widget's settings file lists has that value in its bar entry.
configured() {
  [ -n "$WIDGET" ] && [ -f "$WIDGET_SETTINGS" ] || return 0
  jq -e -n --arg id "$WIDGET" --slurpfile want "$WIDGET_SETTINGS" --slurpfile shell "$JSON" '
    ([$shell[0].bar.layout[]?[]? | select(.id == $id)][0] // {}) as $entry
    | $want[0] | to_entries | all(.value == $entry[.key])' >/dev/null
}

case "$MODE" in
check)
  positioned && sized && replaced && configured
  ;;
install)
  if rest | grep -q '^[[:space:]]*\[bar\]'; then
    echo "$TOML has its own [bar] table: move its keys into the opt-in, or remove it" >&2
    exit 1
  fi
  positioned || omarchy bar position "$POSITION"
  mkdir -p "$(dirname "$TOML")"
  others=$(rest)
  if [ -n "$others" ]; then
    { printf '%s\n\n' "$others"; block; } > "$TOML"
  else
    block > "$TOML"
  fi
  if [ -n "$WIDGET" ] && ! replaced; then
    enabled "$WIDGET" || { echo "$WIDGET isn't installed and enabled: add it to omarchy-plugins" >&2; exit 1; }
    if on_bar "$STOCK"; then omarchy bar move "$WIDGET" --after "$STOCK"; fi
    if enabled "$STOCK"; then omarchy plugin disable "$STOCK"; fi
  fi
  if ! configured; then
    for key in $(jq -r 'keys[]' "$WIDGET_SETTINGS"); do
      omarchy bar set "$WIDGET" "$key" "$(jq -c --arg k "$key" '.[$k]' "$WIDGET_SETTINGS")" --json >/dev/null
    done
  fi
  positioned && sized && replaced && configured ||
    { echo "the bar's position, thickness or workspace widget isn't what the opt-in names after install" >&2; exit 1; }
  ;;
esac
