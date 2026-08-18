#!/bin/sh
# AnyDesk from a pinned direct rpm (no repo — bump the URL to upgrade).
set -eu

curl -1sLf -o /tmp/anydesk.rpm https://download.anydesk.com/linux/anydesk_8.0.3-1_x86_64.rpm
sudo dnf install -y /tmp/anydesk.rpm
rm -f /tmp/anydesk.rpm
