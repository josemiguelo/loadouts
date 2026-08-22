#!/bin/sh
# Antigravity from its RPM repository (repo file + install).
set -eu

sudo tee /etc/yum.repos.d/antigravity.repo >/dev/null <<'REPO'
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=0
REPO
sudo dnf makecache --repo=antigravity-rpm
sudo dnf install -y antigravity
