#!/bin/sh
# Keep the screen at the brightness you left it at across suspend/hibernate.
#
# The panel's backlight on T2 MacBook Pros is the Apple gmux's
# (gmux_backlight, the device Omarchy's brightness keys drive). Waking from
# deep sleep resets the gmux to its own, bright default, but the driver
# doesn't push the level back, so the kernel's brightness value (what
# `brightnessctl` and Omarchy's OSD read) still says the old level while the
# panel shines brighter. The first brightness key then sets "old level ± 5%"
# on the hardware: a sudden jump down.
#
# A systemd sleep hook fixes it the way Omarchy fixes its own post-sleep
# quirks (/usr/lib/systemd/system-sleep/, the only directory systemd-sleep
# runs): on "post", write the kernel's value back to the device, which makes
# the driver send it to the gmux again. Tested by hand first: that write brings
# the panel straight back to the level from before suspend.
# Modes: `check` / `install` (default).
set -eu

HOOK=/usr/lib/systemd/system-sleep/t2-gmux-backlight

hook_text() {
  cat <<'HOOK_EOF'
#!/bin/sh
# Managed by loadout (t2-gmux-backlight): after suspend/hibernate, send the
# kernel's brightness value back to the gmux, which wakes at its own bright
# default without it.
[ "$1" = post ] || exit 0
device=/sys/class/backlight/gmux_backlight
if [ -w "$device/brightness" ] && level=$(cat "$device/brightness"); then
  echo "$level" > "$device/brightness"
fi
exit 0
HOOK_EOF
}

ready() {
  [ -x "$HOOK" ] && [ "$(cat "$HOOK")" = "$(hook_text)" ]
}

case "${1:-install}" in
check)
  ready
  ;;
install)
  hook_text | sudo tee "$HOOK" >/dev/null
  sudo chmod 755 "$HOOK"
  ready || { echo "$HOOK not in place after install" >&2; exit 1; }
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
