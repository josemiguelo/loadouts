#!/bin/sh
# Voxtype on the GPU (Vulkan) instead of the CPU. Omarchy's dictation
# installer tries `voxtype setup gpu --enable` too, but without sudo, and
# tolerates it failing — which it does, since it swaps /usr/bin/voxtype. On
# the MacBookPro16,1 Vulkan picks between the Intel UHD 630 and the AMD
# Radeon Pro 5300M/5500M: much faster transcription, at the cost of waking
# the GPU for each dictation.
#
# The running daemon keeps the binary it started with, hence the restart;
# check therefore asks both: is /usr/bin/voxtype the Vulkan build, and is
# the service running it. A voxtype-bin update that swaps it back shows up
# as pending.
# Modes: `check` / `install` (default).
set -eu

VULKAN=/usr/lib/voxtype/voxtype-vulkan

running_binary() {
  pid=$(systemctl --user show -p MainPID --value voxtype 2>/dev/null)
  [ -n "$pid" ] && [ "$pid" != 0 ] && readlink -f "/proc/$pid/exe"
}

case "${1:-install}" in
check)
  [ "$(readlink -f /usr/bin/voxtype)" = "$VULKAN" ] &&
    [ "$(running_binary)" = "$VULKAN" ]
  ;;
install)
  [ -x "$VULKAN" ] || { echo "no Vulkan build of voxtype at $VULKAN" >&2; exit 1; }
  if [ "$(readlink -f /usr/bin/voxtype)" != "$VULKAN" ]; then
    sudo voxtype setup gpu --enable
  fi
  systemctl --user restart voxtype
  voxtype setup gpu --status
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
