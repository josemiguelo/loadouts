#!/bin/sh
# FiraCode nerd fonts into the user font dir.
set -eu

fonts_target_path="$HOME/.local/share/fonts"

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.3/FiraCode.zip -P "$TEMP_DIR/"
unzip "$TEMP_DIR/FiraCode.zip" -d "$TEMP_DIR/FiraCode"

mkdir -p "$fonts_target_path"
cp "$TEMP_DIR"/FiraCode/Fira\ Code* "$fonts_target_path/"

fc-cache -fv
