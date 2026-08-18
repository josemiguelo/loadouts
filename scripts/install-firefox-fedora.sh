#!/bin/sh
# Firefox rpm with the Cisco OpenH264 repo enabled (codec support).
set -eu

sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1
sudo dnf install -y firefox --allowerasing
