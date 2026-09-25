#!/bin/sh
# Omarchy's firewall (install/config/firewall.sh: ufw, incoming denied,
# forwarding DROP) vs libvirt's default NAT network on virbr0: guests would
# get no DHCP/DNS from the host's dnsmasq (incoming) and no way out through
# the NAT (routed). Omarchy's own pattern for Docker is explicit ufw allow
# rules with a comment; these follow it:
#   ufw allow in on virbr0            DHCP/DNS from guests to the host
#   ufw route allow in on virbr0      guests' traffic out through the NAT
#   ufw route allow out on virbr0     and the replies back in
# The check reads /etc/ufw/user.rules (world-readable) for the three rules
# by their comment, so `loadout status` needs no sudo for it.
# Modes: `check` / `install` (default).
set -eu

RULES=/etc/ufw/user.rules
TAG=libvirt
HEX=$(printf '%s' "$TAG" | od -An -tx1 | tr -d ' \n')

# ufw records each rule as "### tuple ### <action> … <direction>_<iface>
# comment=<hex>"; route rules carry a "route:" prefix on the action.
has() {
  grep -Eq "^### tuple ### $1 .* ${2}_virbr0 comment=$HEX\$" "$RULES" 2>/dev/null
}

ready() {
  has allow in && has 'route:allow' in && has 'route:allow' out
}

case "${1:-install}" in
check)
  ready
  ;;
install)
  has allow in || sudo ufw allow in on virbr0 comment "$TAG"
  has 'route:allow' in || sudo ufw route allow in on virbr0 comment "$TAG"
  has 'route:allow' out || sudo ufw route allow out on virbr0 comment "$TAG"
  ready || { echo "ufw rules for virbr0 not found in $RULES after adding them" >&2; exit 1; }
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
