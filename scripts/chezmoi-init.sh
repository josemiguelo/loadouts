#!/bin/sh
# First-time dotfiles setup: clone + apply, then the machine-private wezterm
# config that chezmoi doesn't manage.
set -eu

sudo chown -R "$USER:$USER" "$HOME/.local"
chezmoi init --apply --verbose --force https://github.com/josemiguelo/.dotfiles.git
echo "return { color_scheme = 'Tokyo Night' }" >"$HOME/.config/wezterm/private.lua"
