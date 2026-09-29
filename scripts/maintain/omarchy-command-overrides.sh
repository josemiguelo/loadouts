#!/bin/sh
# A place for local replacements of Omarchy commands: the directory
# ~/.local/share/omarchy-overrides/bin, first on the PATH of everything
# Hyprland starts. Omarchy puts $OMARCHY_PATH/bin at the front of that PATH
# (default/hypr/envs.lua), ahead of any system directory, so a block in
# ~/.config/hypr/hyprland.lua — loaded after envs.lua — puts this directory in
# front of it the same way, removing it first so reloads don't stack it. The
# fixes that need a replacement (omarchy-keyboard-backlight-guard,
# t2-gmux-backlight) each put or remove their own wrapper there.
# Install reloads Hyprland and restarts the shell, so the shell runs with the
# PATH — only when the block changed or the shell doesn't have it yet. The
# check reads the PATH the evaluated config produces (hypr-option.lua
# env:PATH) and the running shell's.
# Modes: `check` / `install` (default).
set -eu

CONF=$HOME/.config/hypr/hyprland.lua
BEGIN="-- >>> Managed by loadout (omarchy-command-overrides)"
END="-- <<< Managed by loadout (omarchy-command-overrides)"
# The block's earlier owner, moved here.
OLD_BEGIN="-- >>> Managed by loadout (omarchy-keyboard-backlight-guard)"
OLD_END="-- <<< Managed by loadout (omarchy-keyboard-backlight-guard)"
HERE="$(cd "$(dirname "$0")" && pwd)"
PROBE=$HERE/hypr-option.lua
. "$HERE/hypr-live.sh"
. "$HERE/omarchy-overrides-lib.sh"

block_text() {
  cat <<'BLOCK_EOF'
-- >>> Managed by loadout (omarchy-command-overrides)
-- Local replacements of Omarchy commands first on the PATH of everything
-- Hyprland starts, ahead of $OMARCHY_PATH/bin that default/hypr/envs.lua puts
-- first — removed before being added again, so reloads don't stack it.
local overrides = os.getenv("HOME") .. "/.local/share/omarchy-overrides/bin"
local path = { overrides }
for entry in (os.getenv("PATH") or ""):gmatch("[^:]+") do
  if entry ~= overrides then table.insert(path, entry) end
end
hl.env("PATH", table.concat(path, ":"))
-- <<< Managed by loadout (omarchy-command-overrides)
BLOCK_EOF
}

current_block() {
  awk -v b="$BEGIN" -v e="$END" '$0 == b { on = 1 } on { print } $0 == e { on = 0 }' "$CONF" 2>/dev/null
}

first_on() {
  [ "$(printf '%s' "$1" | cut -d: -f1)" = "$OVERRIDES_DIR" ]
}

in_place() {
  [ -d "$OVERRIDES_DIR" ] && [ "$(current_block)" = "$(block_text)" ] || return 1
  ! grep -qxF -e "$OLD_BEGIN" "$CONF" || return 1
  config_path=$(lua "$PROBE" env:PATH) || return 1
  first_on "$config_path" || return 1
  live=$(shell_path)
  [ -z "$live" ] || first_on "$live"
}

case "${1:-install}" in
check)
  in_place
  ;;
install)
  mkdir -p "$OVERRIDES_DIR"
  touch "$CONF"
  if [ "$(current_block)" != "$(block_text)" ] || grep -qxF -e "$OLD_BEGIN" "$CONF"; then
    rest=$(awk -v b="$BEGIN" -v e="$END" -v ob="$OLD_BEGIN" -v oe="$OLD_END" \
      '$0 == b || $0 == ob { skip = 1 } !skip { print } $0 == e || $0 == oe { skip = 0 }' "$CONF")
    { printf '%s\n\n' "$rest"; block_text; } > "$CONF"
  fi
  live=$(shell_path)
  if [ -z "$live" ] || ! first_on "$live"; then
    sig=$(live_instance)
    if [ -z "$sig" ]; then
      echo "Hyprland isn't reachable from here; applies at the next login."
      exit 0
    fi
    HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl -q reload
    HYPRLAND_INSTANCE_SIGNATURE=$sig omarchy-restart-shell >/dev/null
  fi
  in_place || { echo "$OVERRIDES_DIR isn't first on the shell's PATH after install" >&2; exit 1; }
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
