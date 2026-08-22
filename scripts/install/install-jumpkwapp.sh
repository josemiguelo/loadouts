#!/bin/sh
# jumpkwapp pinned release into ~/.local/bin (bump the version to upgrade).
set -eu

JUMPKWAPP_VERSION="v0.01"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$BIN_DIR"
curl -fSL "https://github.com/josemiguelo/jumpkwapp-go/releases/download/${JUMPKWAPP_VERSION}/jumpkwapp-linux-amd64" -o "$BIN_DIR/jumpkwapp"
chmod +x "$BIN_DIR/jumpkwapp"
