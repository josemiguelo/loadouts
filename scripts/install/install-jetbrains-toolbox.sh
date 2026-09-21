#!/bin/sh
# JetBrains Toolbox on Linux as a per-user install, straight from JetBrains'
# release feed. Not a brew cask: casks that write into $HOME record absolute
# paths in the shared Caskroom, so a prefix shared between accounts breaks on
# the next upgrade ("Permission denied ... /home/<other user>/.config").
#
# Lands where Toolbox installs itself, so its own self-updates replace the
# same files. The version file is what `check` reads; Toolbox's self-update
# does not bump it, so `loadout outdated` may show an update Toolbox already
# applied — rerunning this just re-downloads the current release.
# Modes: `check` (prints the installed version) / `install` (default).
set -eu

TOOLBOX_DIR="$HOME/.local/share/JetBrains/Toolbox"
BIN_DIR="$TOOLBOX_DIR/bin"
VERSION_FILE="$BIN_DIR/.loadout-version"
LINK="$HOME/.local/bin/jetbrains-toolbox"
DESKTOP="$HOME/.local/share/applications/jetbrains-toolbox.desktop"
FEED="https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release"

case "${1:-install}" in
  check)
    [ -x "$BIN_DIR/jetbrains-toolbox" ] && [ -L "$LINK" ] && cat "$VERSION_FILE"
    exit $?
    ;;
  install) ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac

release=$(curl -fsSL "$FEED" | python3 -c '
import json, sys
r = json.load(sys.stdin)["TBA"][0]
print(r["build"], r["downloads"]["linux"]["link"])')
build=${release%% *}
url=${release#* }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$url" | tar -xz -C "$TMP"

mkdir -p "$BIN_DIR" "$HOME/.local/bin" "$(dirname "$DESKTOP")"
cp -R "$TMP/jetbrains-toolbox-$build/bin/." "$BIN_DIR/"
ln -sfn "$BIN_DIR/jetbrains-toolbox" "$LINK"
echo "$build" >"$VERSION_FILE"

# Toolbox rewrites this with its own entry (and icon) on first run.
[ -f "$DESKTOP" ] || cat >"$DESKTOP" <<DESK
[Desktop Entry]
Type=Application
Name=JetBrains Toolbox
Exec=$BIN_DIR/jetbrains-toolbox %u
Icon=$BIN_DIR/toolbox-tray-color.png
Categories=Development
StartupWMClass=jetbrains-toolbox
Terminal=false
MimeType=x-scheme-handler/jetbrains;
DESK

# Migration from the cask this replaced: the shared prefix must not keep a
# cask record pointing at another account's home, or `brew upgrade --cask`
# fails for everyone. Whole-directory removal because `brew uninstall` itself
# trips over those paths.
for prefix in /home/linuxbrew/.linuxbrew /opt/homebrew; do
  if [ -d "$prefix/Caskroom/jetbrains-toolbox-linux" ]; then
    echo "removing stale cask record $prefix/Caskroom/jetbrains-toolbox-linux"
    rm -rf "$prefix/Caskroom/jetbrains-toolbox-linux"
    [ -L "$prefix/bin/jetbrains-toolbox" ] && rm -f "$prefix/bin/jetbrains-toolbox"
  fi
done

# The cask's tap has no other consumer; left tapped-but-untrusted it makes
# every brew command warn for accounts that never trusted it.
if sh scripts/install/brew.sh tap-info ublue-os/tap 2>/dev/null | grep -q Installed; then
  sh scripts/install/brew.sh untap ublue-os/tap
fi

echo "jetbrains-toolbox $build installed in $BIN_DIR"
