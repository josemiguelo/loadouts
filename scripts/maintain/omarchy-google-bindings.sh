#!/bin/sh
# Omarchy's email and calendar keys open HEY (default/hypr/bindings/
# applications.lua). This rebinds them to Gmail and Google Calendar in
# ~/.config/hypr/bindings.lua, Omarchy's personal-bindings file, the way its
# own comments say: hl.unbind the key, then bind it again (two binds on one
# key would both fire). The check doesn't read the file's text:
# hypr-option.lua evaluates the whole Lua config and reports what each key
# runs. Install confirms it in the running Hyprland when there is one — by
# description: with a Lua config, hyprctl binds shows every binding as a Lua
# function reference, never the command, so each key's one binding must carry
# the description given here.
# Modes: `check` / `install` (default).
set -eu

CONF=$HOME/.config/hypr/bindings.lua
HERE="$(cd "$(dirname "$0")" && pwd)"
PROBE=$HERE/hypr-option.lua
. "$HERE/hypr-live.sh"

MAIL=https://mail.google.com/
COMPOSE='https://mail.google.com/mail/?view=cm&fs=1'
CALENDAR=https://calendar.google.com/

# What o.bind makes of { webapp = url }.
webapp() {
  echo "omarchy-launch-webapp '$1'"
}

# Every key runs exactly the one command; fails (the probe says why) when the
# config can't be evaluated.
bound() {
  [ "$(lua "$PROBE" "bind:SUPER + SHIFT + E")" = "$(webapp "$MAIL")" ] &&
    [ "$(lua "$PROBE" "bind:SUPER + SHIFT + ALT + E")" = "$(webapp "$COMPOSE")" ] &&
    [ "$(lua "$PROBE" "bind:SUPER + SHIFT + C")" = "$(webapp "$CALENDAR")" ]
}

case "${1:-install}" in
check)
  bound
  ;;
install)
  lua "$PROBE" "bind:SUPER + SHIFT + E" >/dev/null || exit 1
  # Once: if the block is there and still loses, adding it again won't win.
  if ! bound && ! grep -qs 'Managed by loadout (omarchy-google-bindings)' "$CONF"; then
    mkdir -p "$(dirname "$CONF")"
    cat >> "$CONF" <<LUA

-- Managed by loadout (omarchy-google-bindings): Gmail and Google Calendar
-- in HEY's place (scripts/maintain/omarchy-google-bindings.sh).
hl.unbind("SUPER + SHIFT + E")
o.bind("SUPER + SHIFT + E", "Gmail", { webapp = "$MAIL" })
hl.unbind("SUPER + SHIFT + ALT + E")
o.bind("SUPER + SHIFT + ALT + E", "New Gmail message", { webapp = "$COMPOSE" })
hl.unbind("SUPER + SHIFT + C")
o.bind("SUPER + SHIFT + C", "Google Calendar", { webapp = "$CALENDAR" })
LUA
  fi
  bound || { echo "the email/calendar keys still don't open Google after $CONF: something loaded later binds them" >&2; exit 1; }
  sig=$(live_instance)
  if [ -n "$sig" ]; then
    HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl -q reload
    live=$(HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl binds -j)
    # modmask: SUPER 64 + SHIFT 1 (+ ALT 8).
    for want in "65 E Gmail" "73 E New Gmail message" "65 C Google Calendar"; do
      set -- $want
      mask=$1 key=$2
      shift 2
      got=$(printf '%s' "$live" | jq -r --argjson m "$mask" --arg k "$key" \
        '[.[] | select(.modmask == $m and .key == $k) | .description] | join("|")')
      [ "$got" = "$*" ] ||
        { echo "the running Hyprland binds key $key (modmask $mask) to '$got', not '$*'" >&2; exit 1; }
    done
  else
    echo "Hyprland isn't reachable from here; the keys change at the next login."
  fi
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
