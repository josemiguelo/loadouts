#!/bin/sh
# The keyboard backlight came back dark after sleep. Omarchy blanks through
# `omarchy-brightness-keyboard off` (the lock screen and the idle service),
# which saves the current level (brightnessctl -s) and sets 0; waking runs
# `restore`. But `off` saves every time, and blanking repeats while already
# dark (the lock screen re-blanks 5s after waking if untouched), so the second
# `off` saves 0 over the real level and waking restores 0.
#
# Until Omarchy fixes it, a wrapper skips `off` when the light is already 0
# and hands everything else to Omarchy's command. It goes in the directory
# omarchy-command-overrides puts first on the session's PATH (where the shell
# runs the lock and idle code), so the session runs it instead of Omarchy's.
#
# Whether Omarchy is still affected is decided by behavior, not text: its
# `off` runs against a stand-in brightnessctl that reports 0, and saving
# anyway means the wrapper is needed. Once it stops, install removes the
# wrapper. The check requires the session to actually run it (the evaluated
# config's PATH and the running shell's).
# Modes: `check` / `install` (default).
set -eu

COMMAND=omarchy-brightness-keyboard
OLD_WRAPPER=/usr/local/bin/$COMMAND
HERE="$(cd "$(dirname "$0")" && pwd)"
PROBE=$HERE/hypr-option.lua
. "$HERE/omarchy-overrides-lib.sh"
WRAPPER=$OVERRIDES_DIR/$COMMAND

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

guarded() {
  [ -x "$WRAPPER" ] && [ "$(cat "$WRAPPER")" = "$(wrapper_text)" ] && override_active "$COMMAND"
}

case "${1:-install}" in
check)
  if affected; then guarded; else [ ! -e "$WRAPPER" ]; fi
  ;;
install)
  if affected; then
    mkdir -p "$OVERRIDES_DIR"
    wrapper_text > "$WRAPPER"
    chmod 755 "$WRAPPER"
    guarded || { echo "the session doesn't run $WRAPPER: is omarchy-command-overrides installed?" >&2; exit 1; }
  else
    rm -f "$WRAPPER"
    echo "Omarchy's $COMMAND no longer saves over a dark light: wrapper removed."
  fi
  if [ -e "$OLD_WRAPPER" ]; then
    echo "An earlier attempt left $OLD_WRAPPER (unused: Omarchy's bin comes first). Remove it with: sudo rm $OLD_WRAPPER"
  fi
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
