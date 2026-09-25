#!/bin/sh
# lazy.nvim plugins, exactly as ~/.config/nvim/lazy-lock.json pins them (the
# lockfile comes from the chezmoi dotfiles). Two questions and two actions, one
# script, one headless-nvim helper (nvim-plugins.lua, mode via
# $LOADOUT_NVIM_MODE):
#
#   check      does the disk match the lock? EVERY plugin the spec enables is
#              cloned AND sits on its locked commit — a lock moved on another
#              machine lands here as a file change only; the clone is what
#              runs. (the [scripts.nvim-plugins] check)
#   install    make it so: Lazy's own `restore`.  (the script's run)
#   outdated   is a newer commit available upstream? Lazy's own check, honouring
#              each plugin's version/tag/commit/branch/pin.
#              (the [outdated.nvim-plugins] source)
#   update     move one plugin to what `outdated` reported — Lazy's own update,
#              so Lazy stays the only writer of the pins.
#              (the source's per-row upgrade)
#
# `update` moves the pin in the lockfile chezmoi APPLIES, not the one it keeps:
# dotfiles-apply reports the drift (it refuses to overwrite a file changed
# behind chezmoi's back, so nothing is lost) until the new lock is re-added to
# the dotfiles source. Same hand-off as the asdf pin oracles.
set -eu
# mise's shims, for the neovim the mise config pins (nightly) when this runs
# outside a shell that activated mise.
export PATH="$HOME/.local/bin:${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims:$PATH"

LOCK="${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lazy-lock.json"
LUA="$(cd "$(dirname "$0")" && pwd)/nvim-plugins.lua"

# Run the helper in [mode] on [item]; prints its lines, returns 1 when nvim
# didn't answer (no sentinel). A hung nvim is capped so it can never stall
# loadout.
ask() {
  out=$(mktemp)
  LOADOUT_NVIM_OUT="$out" LOADOUT_NVIM_MODE="$1" LOADOUT_NVIM_ITEM="${2:-}" \
    timeout 120 nvim --headless -n \
    -c "luafile $LUA" -c 'qa!' </dev/null >/dev/null 2>&1 || true
  if grep -qx '__LOADOUT_NVIM_OK__' "$out" 2>/dev/null; then
    grep -vx '__LOADOUT_NVIM_OK__' "$out" | grep -v '^[[:space:]]*$' || true
    rm -f "$out"
    return 0
  fi
  reason=$(sed -n 's/^__LOADOUT_NVIM_ERR__ //p' "$out" 2>/dev/null)
  rm -f "$out"
  echo "${reason:-nvim did not answer}"
  return 1
}

check() {
  [ -f "$LOCK" ] || { echo "lazy-lock.json not found" >&2; exit 1; }
  command -v nvim >/dev/null 2>&1 || { echo "nvim not found" >&2; exit 1; }
  lines=$(ask check) || { echo "could not ask Lazy: $lines"; exit 1; }
  [ -n "$lines" ] || exit 0
  printf '%s\n' "$lines" | while read -r kind name head locked; do
    case "$kind" in
      missing) echo "missing plugin: $name" ;;
      off-lock) echo "plugin off its lock: $name (installed $head, locked $locked)" ;;
    esac
  done
  exit 1
}

install_all() {
  command -v nvim >/dev/null 2>&1 || { echo "nvim not found" >&2; exit 1; }
  nvim --headless "+Lazy! restore" +qa
}

outdated() {
  # Legitimately silent: this machine has no neovim/lazy to report on.
  command -v nvim >/dev/null 2>&1 || exit 0
  [ -d "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim" ] || exit 0
  # A visible row in the outdated table when Lazy couldn't answer — a broken
  # oracle must never masquerade as "nothing outdated".
  lines=$(ask outdated) || { printf 'nvim-plugins-oracle FAILED FAILED %s\n' "$lines"; exit 0; }
  [ -z "$lines" ] || printf '%s\n' "$lines"
}

update() {
  plugin=${1:?usage: nvim-plugins.sh update <plugin>}
  command -v nvim >/dev/null 2>&1 || { echo "nvim not found" >&2; exit 1; }
  lines=$(ask update "$plugin") || { echo "could not update $plugin: $lines" >&2; exit 1; }
  printf '%s\n' "$lines"
}

case "${1:-install}" in
check) check ;;
install) install_all ;;
outdated) outdated ;;
update) update "${2:-}" ;;
*) echo "usage: $0 [check|install|outdated|update <plugin>]" >&2; exit 2 ;;
esac
