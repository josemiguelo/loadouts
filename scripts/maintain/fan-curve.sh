#!/bin/sh
# t2fanrd fan curve for the MacBookPro16,1 (T2).
#
# The t2fanrd rpm ships no config at all — it reads the original Python
# daemon's path, /etc/t2fand.conf, and writes a default there if absent. So
# this file is entirely ours; keeping it in the repo is the only record of
# what the fan curve is supposed to be.
#
# low/high are the ends of the ramp: below low_temp the fan sits at its
# hardware minimum, above high_temp at its maximum. The min/max RPM come from
# applesmc and differ per fan (Fan1 1836-5616, Fan2 1700-5200) — they are not
# configurable here. speed_curve is one of linear|exponential|logarithmic;
# exponential ramps slowest at the bottom of the band.
#
# t2fanrd reads this only at startup, hence the restart in install.
set -eu

CONF=/etc/t2fand.conf
WANT='[Fan1]
low_temp=55
high_temp=85
speed_curve=exponential
always_full_speed=false

[Fan2]
low_temp=55
high_temp=85
speed_curve=exponential
always_full_speed=false'

case "${1:-install}" in
  check)
    [ "$(cat "$CONF" 2>/dev/null)" = "$WANT" ]
    ;;
  install)
    if [ "$(cat "$CONF" 2>/dev/null)" != "$WANT" ]; then
      printf '%s\n' "$WANT" | sudo tee "$CONF" >/dev/null
      sudo systemctl restart t2fanrd
    fi
    ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
