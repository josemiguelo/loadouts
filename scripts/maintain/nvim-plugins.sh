#!/bin/sh
# lazy.nvim plugins, exactly as ~/.config/nvim/lazy-lock.json pins them (the
# lockfile comes from the chezmoi dotfiles). Two questions, one script, one
# headless-nvim helper (nvim-plugins.lua, mode via $LOADOUT_NVIM_MODE):
#
#   check      does the disk match the lock? EVERY plugin the spec enables is
#              cloned AND sits on its locked commit — a lock moved on another
#              machine lands here as a file change only; the clone is what
#              runs. (the [scripts.nvim-plugins] check)
#   install    make it so: Lazy's own `restore`.  (the script's run)
#   outdated   is a newer commit available upstream? Lazy's own check, honouring
#              each plugin's version/tag/commit/branch/pin. Deliberately NO
#              update mode: Lazy owns the lockfile, and updating plugins is done
#              from inside nvim — loadout only reports.  (the [outdated.nvim-plugins] source)
set -eu
export PATH="$HOME/.local/bin:$HOME/.asdf/shims:$PATH"

LOCK="${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lazy-lock.json"
LUA="$(cd "$(dirname "$0")" && pwd)/nvim-plugins.lua"

# Run the helper in [mode]; prints its lines, returns 1 when nvim didn't
# answer (no sentinel). A hung nvim is capped so it can never stall loadout.
ask() {
  out=$(mktemp)
  LOADOUT_NVIM_OUT="$out" LOADOUT_NVIM_MODE="$1" timeout 120 nvim --headless -n \
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

case "${1:-install}" in
check) check ;;
install) install_all ;;
outdated) outdated ;;
*) echo "usage: $0 [check|install|outdated]" >&2; exit 2 ;;
esac
