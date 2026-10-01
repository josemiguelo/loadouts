#!/bin/sh
# Omarchy shell plugins from git, named by URL in the machine's opt-in (one
# per line in a multi-line entry), each added and enabled with Omarchy's own
# `omarchy plugin add --enable`. A plugin is
# matched to its URL by its checkout's origin under ~/.config/omarchy/plugins
# (the folder is named by the plugin's id, not its URL). Done = every URL
# installed and enabled. Plugins run unsandboxed inside the shell: list only
# ones you trust.
# usage: omarchy-plugins.sh [check] <git-url>...
set -eu

MODE=install
if [ "${1:-}" = check ]; then MODE=check; shift; fi
[ $# -gt 0 ] || { echo "usage: $0 [check] <git-url>..." >&2; exit 2; }

# omarchy-plugin-add's own location (it doesn't follow XDG_CONFIG_HOME).
PLUGINS=$HOME/.config/omarchy/plugins

# A URL without a trailing slash or .git, so both spellings match.
normalize() {
  printf '%s\n' "$1" | sed -e 's#/*$##' -e 's#\.git$##'
}

# The plugin folder cloned from $1, or nothing.
plugin_dir() {
  want=$(normalize "$1")
  for dir in "$PLUGINS"/*/; do
    [ -d "$dir.git" ] || continue
    origin=$(git -C "$dir" config --get remote.origin.url 2>/dev/null) || continue
    if [ "$(normalize "$origin")" = "$want" ]; then
      printf '%s\n' "${dir%/}"
      return 0
    fi
  done
  return 0
}

plugin_id() {
  jq -r .id "$1/manifest.json"
}

enabled() {
  omarchy plugin list --json | jq -e --arg id "$1" 'any(.[]; .id == $id and .enabled)' >/dev/null
}

# The URLs not yet installed and enabled.
pending() {
  for url in "$@"; do
    dir=$(plugin_dir "$url")
    if [ -z "$dir" ] || ! enabled "$(plugin_id "$dir")"; then
      echo "$url"
    fi
  done
  return 0
}

case "$MODE" in
check)
  left=$(pending "$@")
  [ -z "$left" ] || { echo "not installed and enabled: $(echo $left)"; exit 1; }
  ;;
install)
  for url in $(pending "$@"); do
    dir=$(plugin_dir "$url")
    if [ -z "$dir" ]; then
      omarchy plugin add "$url" --enable --yes
    else
      omarchy plugin enable "$(plugin_id "$dir")"
    fi
  done
  left=$(pending "$@")
  [ -z "$left" ] || { echo "not installed and enabled: $(echo $left)" >&2; exit 1; }
  ;;
esac
