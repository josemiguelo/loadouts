#!/bin/sh
# libvirt on Arch, ready for virt-manager on qemu:///system without root:
#   - libvirtd.service enabled and running (the monolithic daemon, as on
#     Fedora; it also autostarts guests marked to autostart)
#   - the login user in Arch's `libvirt` group, which libvirt's polkit rule
#     lets manage the system connection (takes effect at the next login)
#   - the `default` NAT network started and set to autostart
# Checks read only what a user can see without sudo: the service and the
# group. The network is set up by install, idempotently.
# Modes: `check` / `install` (default).
set -eu

in_group() { getent group libvirt | cut -d: -f4 | tr ',' '\n' | grep -qx "$USER"; }

case "${1:-install}" in
check)
  systemctl -q is-enabled libvirtd.service && systemctl -q is-active libvirtd.service && in_group
  ;;
install)
  sudo systemctl enable --now libvirtd.service
  in_group || { sudo usermod -aG libvirt "$USER"; echo "added $USER to libvirt — takes effect at the next login"; }
  if ! sudo virsh -c qemu:///system net-info default 2>/dev/null | grep -q '^Autostart: *yes'; then
    sudo virsh -c qemu:///system net-autostart default
  fi
  if ! sudo virsh -c qemu:///system net-info default 2>/dev/null | grep -q '^Active: *yes'; then
    sudo virsh -c qemu:///system net-start default
  fi
  sudo virsh -c qemu:///system net-list --all
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
