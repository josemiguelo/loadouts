#!/bin/sh
# Sudoless Docker, Omarchy's opt-in: the user in the docker group, so docker,
# lazydocker and the Docker TUI reach the daemon without a polkit/sudo prompt.
# The docker group is root-equivalent (the daemon runs as root: `docker run
# -v /:/host …` is the whole disk), which is why Omarchy leaves users out of
# it and asks first. This runs what omarchy-setup-security-sudoless-docker
# runs once you confirm — its confirmations need a terminal loadout's pane
# doesn't have — and asks Omarchy's own omarchy-sudo-docker whether it's
# configured. Group membership is read when a session starts, so it takes a
# reboot; like Omarchy, install marks reboot-required (omarchy update's
# restart step reads it). An Omarchy migration once took users out of the
# group; the check catches that happening again.
# Modes: `check` / `install` (default).
set -eu

# omarchy-sudo-docker --configured succeeds when Docker would still need sudo.
configured() {
  ! omarchy-sudo-docker --configured
}

case "${1:-install}" in
check)
  configured
  ;;
install)
  if ! configured; then
    sudo usermod -aG docker "$USER"
    omarchy-state set reboot-required
  fi
  configured || { echo "$USER still isn't in the docker group" >&2; exit 1; }
  if omarchy-sudo-docker; then
    echo "Sudoless Docker is configured; it takes effect after a reboot."
  fi
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
