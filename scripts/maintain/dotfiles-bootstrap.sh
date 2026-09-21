#!/bin/sh
# First-time dotfiles bootstrap: clone + apply the chezmoi repo (https — ssh
# keys may not exist yet on a virgin machine). Ownership repair touches ONLY
# files that are actually wrong — a blanket `chown -R ~/.local` walked ~100k
# files to change nothing. Day-to-day convergence is chezmoi-update.sh.
set -eu
# chezmoi is a brew program: only an interactive zsh has brew on PATH, and
# the converge runs from whatever shell the desktop opened (bash, first).
export PATH="$HOME/.local/bin:/home/linuxbrew/.linuxbrew/bin:/opt/homebrew/bin:$PATH"

# Repair-only ownership fix: sudo only when something is actually root-owned.
if [ -n "$(find "$HOME/.local" ! -user "$USER" 2>/dev/null | head -1)" ]; then
  echo "fixing ownership under ~/.local"
  find "$HOME/.local" ! -user "$USER" -print0 | xargs -0 -r sudo chown "$USER:$(id -gn)"
fi

# A desktop that pre-seeds its own Neovim config (omedora builds one on first
# login) must not survive underneath ours: chezmoi only overwrites the files it
# manages, and the leftovers (plugin/, lua/plugins/) still auto-load. First
# bootstrap only — once a source exists the config is ours.
NVIM="$HOME/.config/nvim"
if [ -d "$NVIM" ] && [ ! -d "$HOME/.local/share/chezmoi" ]; then
  echo "moving pre-existing $NVIM aside"
  mv "$NVIM" "$NVIM.pre-chezmoi.$(date +%Y%m%d-%H%M%S)"
fi

# --no-tty: fail with the reason instead of prompting (a prompt would hang
# under captured output).
chezmoi init --apply --verbose --no-tty https://github.com/josemiguelo/.dotfiles.git
