#!/bin/sh
# Slack from packagecloud's rpm repository.
# NOTE: although the URL says fedora 21, that's where latest versions are
# uploaded; they install correctly on current Fedora.
set -eu

sudo rpm --import https://packagecloud.io/slacktechnologies/slack/gpgkey
sudo tee /etc/yum.repos.d/slack.repo >/dev/null <<'REPO'
[slack]
name=Slack
baseurl=https://packagecloud.io/slacktechnologies/slack/fedora/21/$basearch
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://packagecloud.io/slacktechnologies/slack/gpgkey
sslverify=0
metadata_expire=300
REPO
sudo dnf makecache --repo=slack
sudo dnf install -y slack
