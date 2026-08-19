#!/bin/sh
# ngrok v3 binary into ~/.local/bin. equinox ships tgz for linux and zip
# for macOS (the source recipe hardcoded linux-amd64).
set -eu

BIN_DIR="$HOME/.local/bin"
BASE="https://bin.equinox.io/c/bNyj1mQVY4c"

case "$(uname -s)-$(uname -m)" in
Linux-x86_64) FILE="ngrok-v3-stable-linux-amd64.tgz" ;;
Linux-aarch64) FILE="ngrok-v3-stable-linux-arm64.tgz" ;;
Darwin-arm64) FILE="ngrok-v3-stable-darwin-arm64.zip" ;;
Darwin-x86_64) FILE="ngrok-v3-stable-darwin-amd64.zip" ;;
*)
  echo "unsupported platform: $(uname -s)/$(uname -m)" >&2
  exit 1
  ;;
esac

mkdir -p "$BIN_DIR"
case "$FILE" in
*.tgz) curl -sSL "$BASE/$FILE" | tar -xz -C "$BIN_DIR" ngrok ;;
*.zip)
  TMP=$(mktemp -d)
  curl -sSL -o "$TMP/ngrok.zip" "$BASE/$FILE"
  unzip -o "$TMP/ngrok.zip" ngrok -d "$BIN_DIR"
  rm -rf "$TMP"
  ;;
esac
chmod +x "$BIN_DIR/ngrok"
