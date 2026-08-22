#!/bin/sh
# teams-for-linux from its rpm repository (key + repo file + install).
set -eu

curl -1sLf -o /tmp/teams-for-linux.asc https://repo.teamsforlinux.de/teams-for-linux.asc
sudo rpm --import /tmp/teams-for-linux.asc
curl -1sLf https://repo.teamsforlinux.de/rpm/teams-for-linux.repo | sudo tee /etc/yum.repos.d/teams-for-linux.repo >/dev/null
sudo dnf install -y teams-for-linux
