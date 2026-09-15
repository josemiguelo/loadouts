#!/bin/sh
# asdf plugins, exactly as ~/.plugin-versions pins them (the file comes from
# the chezmoi dotfiles; loadout's asdf-plugins oracle moves its pins). The
# check verifies EVERY pinned plugin is installed AND its clone sits on the
# pinned commit — a pin moved on another machine lands here as a file change
# only; the clone is what actually runs. Tools built with them are
# asdf-tools.sh's job, ordered after this.
# Modes: `check` / `install` (default).
set -eu
export PATH="$HOME/.local/bin:$PATH"

PLUGIN_VERSIONS="$HOME/.plugin-versions"

# One "<plugin> <url> <ref>" line per pin, comments and blanks dropped.
pins() {
  [ -f "$PLUGIN_VERSIONS" ] || return 0
  while read -r plugin url ref _; do
    [ -n "$plugin" ] || continue
    case "$plugin" in \#*) continue ;; esac
    printf '%s %s %s\n' "$plugin" "$url" "$ref"
  done < "$PLUGIN_VERSIONS"
}

check() {
  [ -f "$PLUGIN_VERSIONS" ] || { echo "~/.plugin-versions not found" >&2; exit 1; }
  asdf plugin list 2>/dev/null | grep -q '^asdf-plugin-manager$' || {
    echo "missing plugin: asdf-plugin-manager"
    exit 1
  }
  status=0
  pins | while read -r plugin _url ref; do
    dir="$HOME/.asdf/plugins/$plugin"
    if [ ! -d "$dir/.git" ]; then
      echo "missing plugin: $plugin"
      exit 1
    fi
    head=$(git -C "$dir" rev-parse HEAD 2>/dev/null) || { echo "missing plugin: $plugin"; exit 1; }
    if [ "$head" != "$ref" ]; then
      printf 'plugin behind its pin: %s (installed %.9s, pinned %.9s)\n' "$plugin" "$head" "$ref"
      exit 1
    fi
  done || status=1
  exit $status
}

install_all() {
  # asdf-plugin-manager reads ./.plugin-versions from the cwd — $HOME.
  cd "$HOME"
  if asdf plugin list 2>/dev/null | grep -q '^asdf-plugin-manager$'; then
    echo "asdf-plugin-manager already installed"
  else
    asdf plugin add asdf-plugin-manager https://github.com/asdf-community/asdf-plugin-manager.git
    asdf install asdf-plugin-manager 1.5.0 # sync this version with asdf config files
  fi
  [ -f "$PLUGIN_VERSIONS" ] || { echo "~/.plugin-versions not found - there was a problem with the chezmoi setup" >&2; exit 1; }

  # Adds what's missing and checks out the pin for those; a plugin already
  # here is left where it is (asdf refuses to re-add), so move it ourselves.
  "$HOME/.asdf/shims/asdf-plugin-manager" add-all
  pins | while read -r plugin _url ref; do
    dir="$HOME/.asdf/plugins/$plugin"
    [ -d "$dir/.git" ] || continue
    [ "$(git -C "$dir" rev-parse HEAD)" = "$ref" ] && continue
    echo "moving plugin $plugin to its pin $ref"
    git -C "$dir" fetch -q origin && git -C "$dir" checkout -q "$ref"
  done
}

case "${1:-install}" in
check) check ;;
install) install_all ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
