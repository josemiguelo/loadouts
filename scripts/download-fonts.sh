#!/bin/sh
# FiraCode nerd fonts into the user font dir. macOS registers fonts placed
# in ~/Library/Fonts automatically; Linux needs fc-cache after copying.
# Modes: `check` (fonts present?) / `install` (default).
set -eu

if [ "$(uname -s)" = "Darwin" ]; then
  fonts_target_path="$HOME/Library/Fonts"
else
  fonts_target_path="$HOME/.local/share/fonts"
fi

case "${1:-install}" in
check)
  ls "$fonts_target_path"/Fira\ Code* >/dev/null 2>&1
  exit $?
  ;;
install) ;;
*)
  echo "usage: $0 [check|install]" >&2
  exit 2
  ;;
esac

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

curl -fsSL -o "$TEMP_DIR/FiraCode.zip" \
  https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.3/FiraCode.zip
unzip "$TEMP_DIR/FiraCode.zip" -d "$TEMP_DIR/FiraCode"

mkdir -p "$fonts_target_path"
cp "$TEMP_DIR"/FiraCode/Fira\ Code* "$fonts_target_path/"

if [ "$(uname -s)" != "Darwin" ]; then
  fc-cache -fv
fi
