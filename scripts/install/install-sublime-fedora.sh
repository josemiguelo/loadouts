#!/bin/sh
# Sublime Text from sublimehq's rpm repository (key + repo + install).
set -eu

sudo rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg
sudo dnf config-manager addrepo --overwrite --from-repofile="https://download.sublimetext.com/rpm/stable/$(uname -m)/sublime-text.repo"
sudo dnf makecache --repo=sublime-text
sudo dnf install -y sublime-text
