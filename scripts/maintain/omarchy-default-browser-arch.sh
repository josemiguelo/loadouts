#!/bin/sh
# Omarchy's default browser (xdg-settings default-web-browser, which Omarchy's
# launchers and every XDG handler use), set the native way: `omarchy default
# browser <name>`. Arch's packages already use the desktop ids Omarchy
# expects, so no desktop-id alias is needed.
# usage: omarchy-default-browser-arch.sh <browser>
set -eu
BROWSER_NAME=${1:?usage: omarchy-default-browser-arch.sh <browser>}
command -v "$BROWSER_NAME" >/dev/null 2>&1 || { echo "$BROWSER_NAME is not installed" >&2; exit 1; }
omarchy default browser "$BROWSER_NAME"
