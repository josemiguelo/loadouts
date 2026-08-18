#!/bin/sh
# kitty on Fedora comes from the solopasha/kitty COPR (fresher than the
# distro package). Needs the dnf copr command (programs.dnf-plugins-core).
set -eu

sudo dnf copr enable -y solopasha/kitty
sudo dnf install -y kitty
