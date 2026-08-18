#!/bin/sh
# asdf installed as a plain binary from its GitHub release.
set -eu

ASDF_VERSION="0.18.0"
BIN_DIR="$HOME/.local/bin"
ASDF_DATA_DIR="$HOME/.asdf"

ARCH=$(uname -m)
case ${ARCH} in
x86_64) ARCH_TYPE="amd64" ;;
aarch64) ARCH_TYPE="arm64" ;;
*)
  echo "unsupported architecture: ${ARCH}" >&2
  exit 1
  ;;
esac

mkdir -p "$BIN_DIR"
mkdir -p "$ASDF_DATA_DIR"/installs "$ASDF_DATA_DIR"/plugins "$ASDF_DATA_DIR"/shims

URL="https://github.com/asdf-vm/asdf/releases/download/v${ASDF_VERSION}/asdf-v${ASDF_VERSION}-linux-${ARCH_TYPE}.tar.gz"
curl -sSL "$URL" | tar -xz -C "$BIN_DIR" asdf
chmod +x "${BIN_DIR}/asdf"
chmod -R u+rwX,go+rX,go-w "$ASDF_DATA_DIR"
