#!/bin/sh
# The workspace-layout bar widget: omarchy-workspace-layout/plugin is an
# Omarchy shell plugin showing the focused workspace's tiling layout (click
# toggles it, like SUPER + L), installed into ~/.config/omarchy/plugins/ and
# enabled. Its place on the bar comes from omarchy-bar-widgets. The check
# compares the plugin with the repo's and requires it enabled.
# Modes: `check` / `install` (default).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC=$HERE/omarchy-workspace-layout/plugin
PLUGIN_ID=josemiguelo.workspace-layout
PLUGIN_DIR=$HOME/.config/omarchy/plugins/$PLUGIN_ID
PLUGIN_FILES="manifest.json WorkspaceLayout.qml"

plugin_copied() {
  for f in $PLUGIN_FILES; do
    [ -f "$PLUGIN_DIR/$f" ] && cmp -s "$SRC/$f" "$PLUGIN_DIR/$f" || return 1
  done
}

plugin_enabled() {
  omarchy plugin list --json 2>/dev/null |
    jq -e --arg id "$PLUGIN_ID" 'any(.[]; .id == $id and .enabled)' >/dev/null
}

case "${1:-install}" in
check)
  plugin_copied && plugin_enabled
  ;;
install)
  changed=no
  plugin_copied || changed=yes
  mkdir -p "$PLUGIN_DIR"
  for f in $PLUGIN_FILES; do cp "$SRC/$f" "$PLUGIN_DIR/$f"; done
  # Enabling goes through the running shell. A loaded plugin keeps its old
  # QML, even across disable/enable, until the shell restarts.
  omarchy-shell shell rescanPlugins >/dev/null
  plugin_enabled || omarchy plugin enable "$PLUGIN_ID" >/dev/null ||
    { echo "couldn't enable the $PLUGIN_ID shell plugin (is omarchy-shell running?)" >&2; exit 1; }
  if [ "$changed" = yes ]; then
    omarchy restart shell >/dev/null 2>&1 || echo "restart the Omarchy shell to load the new $PLUGIN_ID (omarchy restart shell)" >&2
  fi
  plugin_copied && plugin_enabled
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
