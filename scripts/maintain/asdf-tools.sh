#!/bin/sh
# asdf tool builds: everything ~/.tool-versions declares (the file comes from
# the chezmoi dotfiles). The check verifies that EVERY version listed there is
# actually installed. The plugins that build them are asdf-plugins.sh's job,
# ordered before this.
# Modes: `check` / `install` (default).
set -eu
export PATH="$HOME/.local/bin:$PATH"

TOOL_VERSIONS="$HOME/.tool-versions"

check() {
  [ -f "$TOOL_VERSIONS" ] || { echo "~/.tool-versions not found" >&2; exit 1; }
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
  # asdf reads .tool-versions from the cwd — $HOME (chezmoi), not the repo.
  cd "$HOME"
  if [ -f "$TOOL_VERSIONS" ]; then
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
