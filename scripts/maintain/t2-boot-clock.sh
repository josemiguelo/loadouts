#!/bin/sh
# Keep the T2 Mac's hardware clock set.
#
# The MacBookPro16,1 has one real, battery-backed RTC living in the EC. It is
# exposed to Linux twice:
#
#   rtc0  legacy CMOS ports. What the kernel reads at boot (hctosys=1), but
#         writes to it are discarded by the firmware — which is where the
#         kernel's 11-minute NTP writeback goes, so it never took effect.
#   rtc1  the ACPI Time and Alarm Device \_SB.PCI0.LPCB.ARTC (ACPI000E). Its
#         _SRT method is the only write that actually sticks.
#
# So nothing in Linux had ever set this clock. It ticked accurately from a
# cold-boot zero, every boot read back 1970-01-28, and systemd bumped that to
# its own build date — leaving the machine ~6 weeks in the past until chrony
# synced. Journal timestamps were wrong and PackageKit's reboot-to-install
# offline updates aborted before rpm ever opened the database.
#
# One write through rtc1 fixes the boot clock permanently (rtc0 reads the same
# EC clock, so hctosys picks it up); the shutdown hook keeps it from drifting.
#
# Reading rtc1 back returns -EIO on a stock kernel: Apple's _GRT fills the ACPI
# validity byte (offset 7) from an EC field it declares as padding, so
# acpi_tad throws away a perfectly good timestamp. Only the read path checks
# that byte, which is why setting the clock works unpatched. The kernel quirk
# that makes rtc1 readable is a separate, optional thing.
set -eu

UNIT=/etc/systemd/system/sync-hwclock.service

# The EC clock, by name rather than by enumeration order — if rtc numbering
# ever shifts, the generated unit stops matching and check reports pending.
rtc_dev() {
  for r in /sys/class/rtc/rtc*; do
    if grep -q ACPI000E "$r/name" 2>/dev/null; then
      echo "/dev/${r##*/}"
      return 0
    fi
  done
  return 1
}

unit_text() {
  cat <<EOF
[Unit]
Description=Write system time to the EC hardware clock at shutdown
DefaultDependencies=no
After=local-fs.target
Before=shutdown.target
Conflicts=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/true
ExecStop=/usr/sbin/hwclock --rtc=$1 --systohc

[Install]
WantedBy=multi-user.target
EOF
}

# Apple-only: elsewhere an ACPI000E device is a normal TAD next to a working
# RTC, and there is nothing to fix.
applicable() {
  [ "$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)" = "Apple Inc." ] || return 1
  DEV=$(rtc_dev) || return 1
}

case "${1:-install}" in
  check)
    applicable || exit 0
    [ "$(cat "$UNIT" 2>/dev/null)" = "$(unit_text "$DEV")" ]
    systemctl is-enabled --quiet sync-hwclock.service
    ;;
  install)
    if ! applicable; then
      echo "No Apple EC clock here; nothing to do."
      exit 0
    fi
    if [ "$(cat "$UNIT" 2>/dev/null)" != "$(unit_text "$DEV")" ]; then
      unit_text "$DEV" | sudo tee "$UNIT" >/dev/null
      sudo systemctl daemon-reload
    fi
    sudo systemctl enable --now sync-hwclock.service
    # Set it now, so the fix applies without waiting for a shutdown.
    sudo /usr/sbin/hwclock --rtc="$DEV" --systohc
    ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
