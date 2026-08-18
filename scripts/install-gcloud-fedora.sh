#!/bin/sh
# Google Cloud CLI from Google's yum repo (repo file + install).
set -eu

sudo tee /etc/yum.repos.d/google-cloud-sdk.repo >/dev/null <<'REPO'
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
REPO
sudo dnf install -y google-cloud-cli
