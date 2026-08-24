#!/bin/sh
# First-time dotfiles bootstrap: clone + apply the chezmoi repo (https — ssh
# keys may not exist yet on a virgin machine). Ownership repair touches ONLY
# files that are actually wrong — a blanket `chown -R ~/.local` walked ~100k
# files to change nothing. Day-to-day convergence is chezmoi-update.sh.
set -eu

# Repair-only ownership fix: sudo only when something is actually root-owned.
if [ -n "$(find "$HOME/.local" ! -user "$USER" 2>/dev/null | head -1)" ]; then
  echo "fixing ownership under ~/.local"
  find "$HOME/.local" ! -user "$USER" -print0 | xargs -0 -r sudo chown "$USER:$(id -gn)"
fi

# --no-tty: fail with the reason instead of prompting (a prompt would hang
# under captured output).
chezmoi init --apply --verbose --no-tty https://github.com/josemiguelo/.dotfiles.git
