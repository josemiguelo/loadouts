#!/bin/sh
# asdf plugins + tool builds: plugin-manager, then everything ~/.tool-versions
# declares (the file comes from the chezmoi dotfiles). The check verifies that
# EVERY version listed there is actually installed.
# Modes: `check` / `install` (default).
set -eu
export PATH="$HOME/.local/bin:$PATH"

TOOL_VERSIONS="$HOME/.tool-versions"

check() {
  [ -f "$TOOL_VERSIONS" ] || { echo "~/.tool-versions not found" >&2; exit 1; }
  asdf plugin list 2>/dev/null | grep -q '^asdf-plugin-manager$' || {
    echo "missing plugin: asdf-plugin-manager"
    exit 1
  }
  status=0
  while read -r plugin versions; do
    [ -n "$plugin" ] || continue
    installed=$(asdf list "$plugin" 2>/dev/null | tr -d ' *') || true
    for v in $versions; do
      if ! printf '%s\n' "$installed" | grep -qxF "$v"; then
        echo "missing: $plugin $v"
        status=1
      fi
    done
  done < "$TOOL_VERSIONS"
  exit $status
}

install_all() {
  # asdf-plugin-manager reads ./.plugin-versions and asdf reads .tool-versions
  # from the cwd — both live in $HOME (chezmoi), not the config repo.
  cd "$HOME"
  if asdf plugin list 2>/dev/null | grep -q '^asdf-plugin-manager$'; then
    echo "asdf-plugin-manager already installed"
  else
    asdf plugin add asdf-plugin-manager https://github.com/asdf-community/asdf-plugin-manager.git
    asdf install asdf-plugin-manager 1.5.0 # sync this version with asdf config files
  fi

  if [ -f "$TOOL_VERSIONS" ]; then
    "$HOME/.asdf/shims/asdf-plugin-manager" add-all
    export CFLAGS="-std=gnu11" # for building python
    asdf install
  else
    echo "~/.tool-versions not found - there was a problem with the chezmoi setup" >&2
    exit 1
  fi
}

case "${1:-install}" in
check) check ;;
install) install_all ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
