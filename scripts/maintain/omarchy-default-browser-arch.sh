#!/bin/sh
# Omarchy's default browser (xdg-settings default-web-browser, which Omarchy's
# launchers and every XDG handler use), set the native way: `omarchy default
# browser <name>`. The Arch version of omarchy-default-browser: Arch's
# packages already use the desktop ids Omarchy expects, so none of the
# Fedora alias is needed — that alias would hide the real launcher here.
# usage: omarchy-default-browser-arch.sh <browser>
set -eu
BROWSER_NAME=${1:?usage: omarchy-default-browser-arch.sh <browser>}
command -v "$BROWSER_NAME" >/dev/null 2>&1 || { echo "$BROWSER_NAME is not installed" >&2; exit 1; }
omarchy default browser "$BROWSER_NAME"
