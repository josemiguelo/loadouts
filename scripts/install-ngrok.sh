#!/bin/sh
# ngrok v3 binary into ~/.local/bin (amd64, as in the source URL).
set -eu

BIN_DIR="$HOME/.local/bin"
URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz"

mkdir -p "$BIN_DIR"
curl -sSL "$URL" | tar -xz -C "$BIN_DIR" ngrok
chmod +x "$BIN_DIR/ngrok"
