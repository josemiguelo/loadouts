#!/bin/sh
# Google Chrome via Fedora's workstation repositories.
set -eu

sudo dnf install -y fedora-workstation-repositories
sudo dnf config-manager setopt google-chrome.enabled=1
sudo dnf install -y google-chrome-stable
