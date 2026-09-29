#!/bin/sh
# The keyboard backlight came back dark after sleep. Omarchy blanks through
# `omarchy-brightness-keyboard off` (the lock screen and the idle service),
# which saves the current level (brightnessctl -s) and sets 0; waking runs
# `restore`. But `off` saves every time, and blanking repeats while already
# dark (the lock screen re-blanks 5s after waking if untouched), so the second
# `off` saves 0 over the real level and waking restores 0.
#
# Until Omarchy fixes it, a wrapper skips `off` when the light is already 0
# and hands everything else to Omarchy's command. It has to come first on the
# PATH of what Hyprland starts — the shell runs the lock and idle code — and
# Omarchy puts $OMARCHY_PATH/bin at the front of that (default/hypr/envs.lua),
# ahead of any system directory. So the wrapper lives in a directory of its
# own, ~/.local/share/omarchy-overrides/bin, which a block in
# ~/.config/hypr/hyprland.lua (loaded after Omarchy's envs.lua) puts first the
# same way Omarchy does its own. Install reloads Hyprland and restarts the
# shell so it runs with that PATH.
#
# Whether Omarchy is still affected is decided by behavior, not text: its
# `off` runs against a stand-in brightnessctl that reports 0, and saving
# anyway means the wrapper is needed. Once it stops, install removes the
# wrapper and the block. The check resolves the command on the PATH the
# evaluated Hyprland config produces (hypr-option.lua env:PATH) and on the
# running shell's.
# Modes: `check` / `install` (default).
set -eu

OMARCHY_BIN=${OMARCHY_PATH:-/usr/share/omarchy}/bin
COMMAND=omarchy-brightness-keyboard
DIR=$HOME/.local/share/omarchy-overrides/bin
WRAPPER=$DIR/$COMMAND
CONF=$HOME/.config/hypr/hyprland.lua
BEGIN="-- >>> Managed by loadout (omarchy-keyboard-backlight-guard)"
END="-- <<< Managed by loadout (omarchy-keyboard-backlight-guard)"
OLD_WRAPPER=/usr/local/bin/$COMMAND
HERE="$(cd "$(dirname "$0")" && pwd)"
PROBE=$HERE/hypr-option.lua
. "$HERE/hypr-live.sh"

wrapper_text() {
  cat <<WRAPPER_EOF
#!/bin/bash
# Managed by loadout (omarchy-keyboard-backlight-guard): skip \`off\` when the
# keyboard backlight is already dark, so a repeated blank doesn't save 0 over
# the level \`restore\` brings back after sleep. Everything else is Omarchy's.
direction=\${1:-up}
[[ \$direction == "--no-osd" ]] && direction=\${2:-up}

if [[ \$direction == "off" ]]; then
  for candidate in /sys/class/leds/*kbd_backlight*; do
    if [[ -e \$candidate ]]; then
      (( \$(brightnessctl -d "\$(basename "\$candidate")" get) == 0 )) && exit 0
      break
    fi
  done
fi

exec "$OMARCHY_BIN/$COMMAND" "\$@"
WRAPPER_EOF
}

block_text() {
  cat <<'BLOCK_EOF'
-- >>> Managed by loadout (omarchy-keyboard-backlight-guard)
-- Local overrides of Omarchy commands first on the PATH of everything
-- Hyprland starts, ahead of $OMARCHY_PATH/bin that default/hypr/envs.lua puts
-- first — removed before being added again, so reloads don't stack it.
local overrides = os.getenv("HOME") .. "/.local/share/omarchy-overrides/bin"
local path = { overrides }
for entry in (os.getenv("PATH") or ""):gmatch("[^:]+") do
  if entry ~= overrides then table.insert(path, entry) end
end
hl.env("PATH", table.concat(path, ":"))
-- <<< Managed by loadout (omarchy-keyboard-backlight-guard)
BLOCK_EOF
}

# Run a command's `off` against a stand-in brightnessctl whose light is at
# $2; succeed when it saved (brightnessctl -s…).
saves_when() {
  tmp=$(mktemp -d)
  cat > "$tmp/brightnessctl" <<STUB
#!/bin/sh
case " \$* " in
*" get "*) echo $2 ;;
*" max "*) echo 100 ;;
esac
case "\$1" in -s*) touch "$tmp/saved" ;; esac
exit 0
STUB
  chmod +x "$tmp/brightnessctl"
  PATH="$tmp:$PATH" "$1" off >/dev/null 2>&1 || true
  saved=1
  [ -e "$tmp/saved" ] && saved=0
  rm -rf "$tmp"
  return $saved
}

# Omarchy's own command still saves over an already-dark light.
affected() {
  saves_when "$OMARCHY_BIN/$COMMAND" 0
}

# The first $COMMAND on a PATH.
resolve() {
  printf '%s\n' "$1" | tr ':' '\n' | while IFS= read -r d; do
    if [ -n "$d" ] && [ -x "$d/$COMMAND" ]; then
      echo "$d/$COMMAND"
      break
    fi
  done
}

# The running Omarchy shell's PATH, or nothing.
shell_path() {
  pid=$(pgrep -x quickshell | head -n1 || true)
  [ -n "$pid" ] && tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^PATH=//p'
  return 0
}

guarded() {
  [ -x "$WRAPPER" ] && [ "$(cat "$WRAPPER")" = "$(wrapper_text)" ] || return 1
  config_path=$(lua "$PROBE" env:PATH) || return 1
  [ "$(resolve "$config_path")" = "$WRAPPER" ] || return 1
  live=$(shell_path)
  [ -z "$live" ] || [ "$(resolve "$live")" = "$WRAPPER" ]
}

unguarded() {
  [ ! -e "$WRAPPER" ] && ! grep -qxF "$BEGIN" "$CONF" 2>/dev/null
}

# Rewrite the block in hyprland.lua; $1 = "keep" writes it, anything else drops it.
write_block() {
  touch "$CONF"
  rest=$(awk -v b="$BEGIN" -v e="$END" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' "$CONF")
  if [ "$1" = keep ]; then
    { printf '%s\n\n' "$rest"; block_text; } > "$CONF"
  else
    printf '%s\n' "$rest" > "$CONF"
  fi
}

# Reload Hyprland, then restart the shell from it so the shell gets the PATH.
apply_live() {
  sig=$(live_instance)
  if [ -z "$sig" ]; then
    echo "Hyprland isn't reachable from here; applies at the next login."
    return 1
  fi
  HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl -q reload
  HYPRLAND_INSTANCE_SIGNATURE=$sig omarchy-restart-shell >/dev/null
}

case "${1:-install}" in
check)
  if affected; then guarded; else unguarded; fi
  ;;
install)
  if affected; then
    mkdir -p "$DIR"
    wrapper_text > "$WRAPPER"
    chmod 755 "$WRAPPER"
    write_block keep
    apply_live || exit 0
    guarded || { echo "the Omarchy shell doesn't run $WRAPPER after install" >&2; exit 1; }
  else
    rm -f "$WRAPPER"
    write_block drop
    apply_live || exit 0
    echo "Omarchy's $COMMAND no longer saves over a dark light: wrapper removed."
  fi
  if [ -e "$OLD_WRAPPER" ]; then
    echo "An earlier attempt left $OLD_WRAPPER (unused: Omarchy's bin comes first). Remove it with: sudo rm $OLD_WRAPPER"
  fi
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
