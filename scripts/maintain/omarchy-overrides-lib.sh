# Sourced by the scripts that override an Omarchy command (see
# omarchy-command-overrides.sh). Everything Hyprland starts — the shell with
# its lock and idle code included — finds commands on a PATH that starts with
# OVERRIDES_DIR (ahead of Omarchy's own $OMARCHY_PATH/bin), so a wrapper there
# replaces the Omarchy command of the same name. Needs PROBE (hypr-option.lua).

OVERRIDES_DIR=$HOME/.local/share/omarchy-overrides/bin
OMARCHY_BIN=${OMARCHY_PATH:-/usr/share/omarchy}/bin

# The first $2 on the PATH $1, or nothing.
resolve_on() {
  printf '%s\n' "$1" | tr ':' '\n' | while IFS= read -r d; do
    if [ -n "$d" ] && [ -x "$d/$2" ]; then
      echo "$d/$2"
      break
    fi
  done
}

# The running Omarchy shell's PATH, or nothing when it isn't running.
shell_path() {
  pid=$(pgrep -x quickshell | head -n1 || true)
  [ -n "$pid" ] && tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^PATH=//p'
  return 0
}

# The session runs OVERRIDES_DIR/$1 for $1: on the PATH the evaluated Hyprland
# config produces, and on the running shell's.
override_active() {
  config_path=$(lua "$PROBE" env:PATH) || return 1
  [ "$(resolve_on "$config_path" "$1")" = "$OVERRIDES_DIR/$1" ] || return 1
  live=$(shell_path)
  [ -z "$live" ] || [ "$(resolve_on "$live" "$1")" = "$OVERRIDES_DIR/$1" ]
}
