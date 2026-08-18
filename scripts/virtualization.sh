#!/bin/sh
# Virtualization stack. dnf's group-installed marker is unreliable (packages
# can arrive without it), so check verifies the member packages themselves;
# install still uses the group for faithful dependency resolution.
set -eu

PKGS="virt-manager virt-install libvirt-daemon libvirt-daemon-kvm libvirt-daemon-config-network libvirt-client qemu-kvm"

case "${1:-install}" in
  check)
    rpm -q $PKGS >/dev/null
    rpm -q libvirt-daemon
    ;;
  install)
    sudo dnf group install -y virtualization
    ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
