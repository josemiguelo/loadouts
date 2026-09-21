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

# GitHub's host key, so the first ssh clone/fetch (dotfiles, loadout sync)
# never stops at an interactive "authenticity of host" prompt.
KNOWN_HOSTS="$HOME/.ssh/known_hosts"
touch "$KNOWN_HOSTS"
chmod 600 "$KNOWN_HOSTS"
if ! ssh-keygen -F github.com -f "$KNOWN_HOSTS" >/dev/null; then
  ssh-keyscan -t ed25519 github.com 2>/dev/null >>"$KNOWN_HOSTS"
fi

SSH_CONFIG="$HOME/.ssh/config"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"
if ! grep -q "AddKeysToAgent yes" "$SSH_CONFIG"; then
  printf '\nHost *\n    AddKeysToAgent yes\n    IdentityFile %s\n' "$SSH_KEY" >>"$SSH_CONFIG"
fi

# The agent itself. The dotfiles point SSH_AUTH_SOCK at the socket of
# openssh's ssh-agent.socket user unit, which Fedora installs but never
# enables for a new account — without this, ssh-add fails with "Error
# connecting to agent". (macOS runs its own agent via launchd.)
if [ "$(uname -s)" = "Linux" ] && ! systemctl --user -q is-enabled ssh-agent.socket 2>/dev/null; then
  systemctl --user enable --now ssh-agent.socket
fi
