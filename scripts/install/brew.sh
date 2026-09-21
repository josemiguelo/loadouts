#!/bin/sh
# brew by absolute path, so converging never depends on the shell having run
# `brew shellenv` (on a fresh machine the dotfiles that do that come AFTER the
# programs). Whichever prefix exists wins; a PATH brew is honoured first so a
# custom prefix still works. Every brew/brew-cask command in the manifest
# runs through here: `sh scripts/install/brew.sh <brew args...>`.
set -eu

for b in "$(command -v brew 2>/dev/null || true)" \
         /opt/homebrew/bin/brew \
         /home/linuxbrew/.linuxbrew/bin/brew; do
  if [ -n "$b" ] && [ -x "$b" ]; then
    exec "$b" "$@"
  fi
done

echo "brew is not installed (setup-brew installs it on Fedora)" >&2
exit 1
