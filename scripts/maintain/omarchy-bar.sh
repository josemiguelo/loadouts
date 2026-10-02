#!/bin/sh
# The Omarchy bar's position, thickness and, optionally, the widget that
# replaces the stock workspace numbers, from the machine's opt-in
# ("omarchy-bar bottom 30 io.github.jburchel.workspace-nameplates").
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
# A workspace widget takes the stock widget's place: moved right after
# omarchy.workspaces while that one is on the bar, then the stock one is
# disabled. A widget with a folder here (omarchy-bar/<id>/, a plugin of this
# repo's own) is installed from it into ~/.config/omarchy/plugins/ and the
# shell restarted when its files change (a loaded plugin keeps its old QML
# until then); any other widget comes from omarchy-plugins. Its own settings
# stay in its shell.json entry, untouched here.
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
LOCAL=$HERE/omarchy-bar/$WIDGET
DEPLOYED=$HOME/.config/omarchy/plugins/$WIDGET
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

own_widget() {
  [ -n "$WIDGET" ] && [ -f "$LOCAL/manifest.json" ]
}

# The repo's copy of an own widget is the deployed one.
deployed() {
  own_widget || return 0
  [ -d "$DEPLOYED" ] && diff -r -q "$LOCAL" "$DEPLOYED" >/dev/null
}

# No widget named, or it's on the bar and the stock one is off.
replaced() {
  [ -z "$WIDGET" ] || { deployed && enabled "$WIDGET" && on_bar "$WIDGET" && ! enabled "$STOCK"; }
}

case "$MODE" in
check)
  positioned && sized && replaced
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
    if own_widget && ! deployed; then
      fresh=no
      [ -d "$DEPLOYED" ] || fresh=yes
      mkdir -p "$DEPLOYED"
      cp -r "$LOCAL/." "$DEPLOYED/"
      omarchy-shell shell rescanPlugins >/dev/null
      enabled "$WIDGET" || omarchy plugin enable "$WIDGET" >/dev/null
      [ "$fresh" = yes ] || omarchy restart shell >/dev/null 2>&1 ||
        echo "restart the Omarchy shell to load the new $WIDGET (omarchy restart shell)" >&2
    fi
    enabled "$WIDGET" || { echo "$WIDGET isn't installed and enabled: add it to omarchy-plugins" >&2; exit 1; }
    if on_bar "$STOCK"; then omarchy bar move "$WIDGET" --after "$STOCK"; fi
    if enabled "$STOCK"; then omarchy plugin disable "$STOCK"; fi
  fi
  positioned && sized && replaced ||
    { echo "the bar's position, thickness or workspace widget isn't what the opt-in names after install" >&2; exit 1; }
  ;;
esac
