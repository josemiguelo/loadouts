#!/bin/sh
# Keychron keyboards configurable from Keychron's web Launcher
# (launcher.keychron.com). The Launcher talks to the keyboard over WebHID,
# which needs the browser to open the keyboard's /dev/hidraw* nodes; those
# are root-only by default, so the Launcher just says "connecting" forever
# (no console error). A udev rule gives the logged-in user access to
# Keychron's (vendor 3434) hidraw nodes through uaccess — Keychron's own
# Linux instructions, and the rule Omarchy ships for the Framework 16's QMK
# modules (default/udev/framework16-qmk-hid.rules) and in open PR #9545 for
# Keychron RGB. Numbered 50- like Omarchy's, so the uaccess tag is set before
# 73-seat-late applies the ACL. Tested first with a temporary setfacl on the
# USB hidraw nodes: the Launcher connected.
# The check wants the rule in place and, when a Keychron is plugged in over
# USB, every one of its hidraw nodes readable and writable by this user.
# Modes: `check` / `install` (default).
set -eu

RULE=/etc/udev/rules.d/50-keychron-hid.rules

rule_text() {
  cat <<'RULE_EOF'
# Managed by loadout (keychron-launcher-access): let the logged-in user open
# Keychron keyboards' HID nodes, so the Keychron Launcher (WebHID) can connect.
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", MODE="0660", TAG+="uaccess"
RULE_EOF
}

# /dev/hidrawN of every Keychron connected over USB (bus 0003).
keychron_nodes() {
  for h in /sys/class/hidraw/hidraw*; do
    [ -e "$h/device/uevent" ] || continue
    if grep -q '^HID_ID=0003:00003434:' "$h/device/uevent"; then
      echo "/dev/${h##*/}"
    fi
  done
}

accessible() {
  for node in $(keychron_nodes); do
    [ -r "$node" ] && [ -w "$node" ] || return 1
  done
  return 0
}

ready() {
  [ -f "$RULE" ] && [ "$(cat "$RULE")" = "$(rule_text)" ] && accessible
}

case "${1:-install}" in
check)
  ready
  ;;
install)
  if [ ! -f "$RULE" ] || [ "$(cat "$RULE")" != "$(rule_text)" ]; then
    rule_text | sudo tee "$RULE" >/dev/null
  fi
  sudo udevadm control --reload
  # Re-run the rules for the hidraw nodes now, so a Keychron already plugged
  # in gets access without replugging.
  sudo udevadm trigger --subsystem-match=hidraw --action=change
  sudo udevadm settle
  ready || { echo "$RULE is in place but a Keychron hidraw node still isn't accessible" >&2; exit 1; }
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
