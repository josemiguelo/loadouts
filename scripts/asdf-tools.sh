#!/bin/sh
# asdf plugins + tool builds: plugin-manager, then everything ~/.tool-versions
# declares (the file comes from the chezmoi dotfiles).
set -eu
export PATH="$HOME/.local/bin:$PATH"

if asdf plugin list 2>/dev/null | grep -q '^asdf-plugin-manager$'; then
  echo "asdf-plugin-manager already installed"
else
  asdf plugin add asdf-plugin-manager https://github.com/asdf-community/asdf-plugin-manager.git
  asdf install asdf-plugin-manager 1.5.0 # sync this version with asdf config files
fi

if [ -f "$HOME/.tool-versions" ]; then
  "$HOME/.asdf/shims/asdf-plugin-manager" add-all
  export CFLAGS="-std=gnu11" # for building python
  asdf install
else
  echo "~/.tool-versions not found - there was a problem with the chezmoi setup" >&2
  exit 1
fi
