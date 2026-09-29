#!/bin/sh
# Keep the screen at the brightness you left it at, across suspend/hibernate
# and across reboots.
#
# The panel's backlight on T2 MacBook Pros is the Apple gmux's
# (gmux_backlight, the device Omarchy's brightness keys drive).
#
# Sleep: waking from deep sleep resets the gmux to its own, bright default,
# but the driver doesn't push the level back, so the kernel's brightness value
# (what `brightnessctl` and Omarchy's OSD read) still says the old level while
# the panel shines brighter. The first brightness key then sets "old level ±
# 5%" on the hardware: a sudden jump down. A systemd sleep hook fixes it the
# way Omarchy fixes its own post-sleep quirks (/usr/lib/systemd/system-sleep/,
# the only directory systemd-sleep runs): on "post", write the kernel's value
# back to the device, which makes the driver send it to the gmux again. Tested
# by hand first: that write brings the panel straight back to its level.
#
# Reboots: systemd saves and restores every backlight through one udev rule
# (99-systemd.rules), which also imports path_id. The gmux sits on the PNP bus
# (/devices/pnp0/00:00), path_id can't place it and fails, and a failed import
# cancels the whole rule: no systemd tag, no systemd-backlight@ unit, so the
# level was never saved or restored. A rule of our own tags it and pulls the
# unit in without path_id, and names it (ID_PATH, which the saved file under
# /var/lib/systemd/backlight/ is named after) by its ACPI id. systemd's
# restore floor stays: never below 5%.
# Modes: `check` / `install` (default).
set -eu

HOOK=/usr/lib/systemd/system-sleep/t2-gmux-backlight
RULE=/etc/udev/rules.d/99-gmux-backlight.rules
DEVICE=/sys/class/backlight/gmux_backlight
UNIT=systemd-backlight@backlight:gmux_backlight.service

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

rule_text() {
  cat <<'RULE_EOF'
# Managed by loadout (t2-gmux-backlight): save and restore the gmux backlight
# across reboots. 99-systemd.rules' backlight rule imports path_id, which
# fails for this PNP-bus device and cancels the rule, so tag it here instead.
SUBSYSTEM=="backlight", KERNEL=="gmux_backlight", ENV{ID_PATH}="acpi-APP000B", TAG+="systemd", ENV{SYSTEMD_WANTS}+="systemd-backlight@backlight:$name.service"
RULE_EOF
}

hook_ready() {
  [ -x "$HOOK" ] && [ "$(cat "$HOOK")" = "$(hook_text)" ]
}

# The rule is in place and udev applied it to the device.
rule_ready() {
  [ -f "$RULE" ] && [ "$(cat "$RULE")" = "$(rule_text)" ] || return 1
  [ -e "$DEVICE" ] || return 0
  props=$(udevadm info --query=property "$DEVICE")
  printf '%s\n' "$props" | grep -q '^TAGS=.*:systemd:' &&
    printf '%s\n' "$props" | grep -qx "SYSTEMD_WANTS=.*$UNIT.*"
}

case "${1:-install}" in
check)
  hook_ready && rule_ready
  ;;
install)
  hook_text | sudo tee "$HOOK" >/dev/null
  sudo chmod 755 "$HOOK"
  rule_text | sudo tee "$RULE" >/dev/null
  sudo udevadm control --reload
  if [ -e "$DEVICE" ]; then
    # Re-run the rules for the device now, so systemd picks the unit up
    # without waiting for the next boot.
    sudo udevadm trigger --action=add --settle "$DEVICE"
  fi
  hook_ready || { echo "$HOOK not in place after install" >&2; exit 1; }
  rule_ready || { echo "udev doesn't tag $DEVICE for $UNIT after install" >&2; exit 1; }
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
