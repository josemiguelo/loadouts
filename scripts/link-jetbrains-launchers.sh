#!/bin/sh
# Symlink JetBrains Toolbox IDE launcher scripts into ~/.local/bin.
# check mode: every Toolbox script must be symlinked (nothing to do when the
# Toolbox scripts dir doesn't exist yet).
set -eu

SCRIPTS_DIR="$HOME/.local/share/JetBrains/Toolbox/scripts"
BIN_DIR="$HOME/.local/bin"

case "${1:-install}" in
  check)
    [ -d "$SCRIPTS_DIR" ] || exit 0
    for script in "$SCRIPTS_DIR"/*; do
      [ -f "$script" ] || continue
      [ -L "$BIN_DIR/$(basename "$script")" ] || exit 1
    done
    ;;
  install)
    if [ ! -d "$SCRIPTS_DIR" ]; then
      echo "JetBrains Toolbox scripts directory not found, skipping"
      exit 0
    fi
    mkdir -p "$BIN_DIR"
    for script in "$SCRIPTS_DIR"/*; do
      [ -f "$script" ] || continue
      name="$(basename "$script")"
      ln -sf "$script" "$BIN_DIR/$name"
      echo "symlinked $name -> $script"
    done
    ;;
  *)
    echo "usage: $0 [check|install]" >&2
    exit 2
    ;;
esac
