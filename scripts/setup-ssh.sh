#!/bin/sh
# Machine ssh key + agent auto-add config.
# usage: setup-ssh.sh <key-name>   (key lands at ~/.ssh/<key-name>)
set -eu

if [ -z "${1:-}" ]; then
  echo "error: no key name given" >&2
  echo "usage: setup-ssh.sh <key-name>" >&2
  exit 2
fi
SSH_KEY="$HOME/.ssh/$1"

if [ ! -f "$SSH_KEY" ]; then
  ssh-keygen -t ed25519 -C "josemiguelo.ochoa@gmail.com" -f "$SSH_KEY" -N ""
  eval "$(ssh-agent -s)"
  ssh-add "$SSH_KEY"
fi

SSH_CONFIG="$HOME/.ssh/config"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"
if ! grep -q "AddKeysToAgent yes" "$SSH_CONFIG"; then
  printf '\nHost *\n    AddKeysToAgent yes\n    IdentityFile %s\n' "$SSH_KEY" >>"$SSH_CONFIG"
fi
