#!/bin/sh
# 1Password from its rpm repository (key + repo + install).
set -eu

curl -fsSL https://downloads.1password.com/linux/keys/1password.asc -o /tmp/1password.asc
sudo rpm --import /tmp/1password.asc
sudo dnf config-manager addrepo \
  --overwrite \
  --id=1password \
  --set=name="1Password Stable Channel" \
  --set=baseurl="https://downloads.1password.com/linux/rpm/stable/\$basearch" \
  --set=enabled=1 \
  --set=gpgcheck=1 \
  --set=repo_gpgcheck=1 \
  --set=gpgkey="file:///tmp/1password.asc"
sudo dnf makecache --repo=1password
sudo dnf install -y 1password
