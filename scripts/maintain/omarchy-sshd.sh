#!/bin/sh
# SSH access to this machine, set up the native way:
# omarchy-setup-security-sshd enables sshd, opens 22/tcp in ufw (rate
# limited, comment "omarchy-sshd"), authorizes a key and then turns password
# logins off (sshd_config.d/10-omarchy-hardening.conf). It authorizes one key
# per call, so it runs once per GitHub key this machine doesn't trust yet.
# ~/.ssh/authorized_keys mirrors https://github.com/<user>.keys: a key
# deleted on GitHub loses access here on the next run. GitHub serves keys
# without their comments, so no email or hostname ends up in this repo.
# The check reads only world-readable files, so `loadout status` needs no
# sudo for it.
# usage: omarchy-sshd.sh [check] <github-user>
set -eu

MODE=install
if [ "${1:-}" = check ]; then MODE=check; shift; fi
GH_USER=${1:?usage: omarchy-sshd.sh [check] <github-user>}

AUTHORIZED_KEYS=$HOME/.ssh/authorized_keys
HARDENING=/etc/ssh/sshd_config.d/10-omarchy-hardening.conf
RULES=/etc/ufw/user.rules
HEX=$(printf '%s' omarchy-sshd | od -An -tx1 | tr -d ' \n')

# "type base64" per line, the part of a key that identifies it.
github_keys() {
  keys=$(curl -fsSL "https://github.com/$GH_USER.keys") ||
    { echo "could not fetch https://github.com/$GH_USER.keys" >&2; return 1; }
  keys=$(printf '%s\n' "$keys" | awk 'NF >= 2 { print $1, $2 }' | sort -u)
  [ -n "$keys" ] || { echo "GitHub user $GH_USER has no SSH keys" >&2; return 1; }
  printf '%s\n' "$keys"
}

authorized() {
  [ -f "$AUTHORIZED_KEYS" ] || return 0
  awk '/^(ssh|ecdsa|sk-)/ { print $1, $2 }' "$AUTHORIZED_KEYS" | sort -u
}

server_ready() {
  systemctl -q is-enabled sshd.service && systemctl -q is-active sshd.service &&
    grep -Eq "^### tuple ### limit tcp 22 .* in comment=$HEX\$" "$RULES" 2>/dev/null &&
    [ -f "$HARDENING" ]
}

case "$MODE" in
check)
  want=$(github_keys)
  server_ready && [ "$want" = "$(authorized)" ]
  ;;
install)
  want=$(github_keys)
  have=$(authorized)
  missing=$(printf '%s\n' "$want" | while read -r key; do
    printf '%s\n' "$have" | grep -qxF "$key" || printf '%s\n' "$key"
  done)
  # Nothing missing but the server isn't fully set up: one call with a key
  # it already trusts redoes the setup steps.
  if [ -z "$missing" ] && ! server_ready; then
    missing=$(printf '%s\n' "$want" | head -n1)
  fi
  # A for loop, not `| while read`: the setup script's sudo and pacman
  # keep the terminal as stdin.
  IFS='
'
  for key in $missing; do
    omarchy-setup-security-sshd --key="$key"
  done
  unset IFS
  # Drop keys GitHub no longer has. Only after the additions: the hardening
  # step refuses to turn passwords off with an empty authorized_keys.
  tmp=$(mktemp)
  printf '%s\n' "$want" | awk 'NR == FNR { keep[$1 " " $2] = 1; next }
    !/^(ssh|ecdsa|sk-)/ || ($1 " " $2) in keep' - "$AUTHORIZED_KEYS" > "$tmp"
  cat "$tmp" > "$AUTHORIZED_KEYS"
  rm -f "$tmp"
  server_ready && [ "$want" = "$(authorized)" ] ||
    { echo "sshd setup or authorized_keys doesn't match GitHub after install" >&2; exit 1; }
  ;;
esac
