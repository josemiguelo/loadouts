#!/bin/sh
# Custom `loadout outdated` oracle: which lazy.nvim plugins does Lazy itself
# consider outdated? We ask Lazy directly (headless nvim -> lazy.manage.check,
# which fetches and populates each plugin._.updates honouring its
# version/tag/commit/branch/pin) instead of the old HEAD-vs-default-branch
# heuristic. That heuristic false-flagged every plugin pinned to a semver tag:
# upstream's default branch moves on, but a `version = "*"` pin stays on the
# newest matching tag, so Lazy (correctly) reports no update while a raw
# HEAD-vs-tip diff shows dozens of commits "behind".
#
# Emits `<name> <current> <candidate> <n> commit(s)` lines (the loadout custom
# source format). Silent when neovim/lazy isn't set up on this machine.
#
# Fail LOUD, not silent: loadout ignores a source's exit code and can't tell a
# crashed oracle from one reporting "nothing outdated". So the Lua helper marks
# success with a `__LOADOUT_NVIM_OK__` sentinel; if that sentinel is missing
# (crash, timeout, Lua error) we print an explicit error row instead of an
# empty result, so a broken check can't hide outdated plugins forever.
set -eu

# Legitimately silent: this machine has no neovim/lazy to report on.
command -v nvim >/dev/null 2>&1 || exit 0
[ -d "$HOME/.local/share/nvim/lazy/lazy.nvim" ] || exit 0

fail() {
  # A visible row in the outdated table: item, current, candidate, note.
  printf 'nvim-plugins-oracle FAILED FAILED %s\n' "$1"
  exit 0
}

lua="$(cd "$(dirname "$0")" && pwd)/nvim-plugins.lua"
[ -f "$lua" ] || fail "oracle helper missing: nvim-plugins.lua"

out=$(mktemp) || fail "could not create temp file"
trap 'rm -f "$out"' EXIT
export LOADOUT_NVIM_OUT="$out"

# Cap the run so a hung nvim can never stall loadout (still surfaced as a fail).
TIMEOUT=
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT=timeout
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT=gtimeout
fi

$TIMEOUT ${TIMEOUT:+120} nvim --headless -n \
  -c "luafile $lua" -c 'qa!' </dev/null >/dev/null 2>&1 || true

result=$(cat "$out" 2>/dev/null || true)

# Success is proven ONLY by the sentinel; anything else is a failure.
if printf '%s\n' "$result" | grep -qx '__LOADOUT_NVIM_OK__'; then
  # Real rows are everything except the sentinel (possibly nothing).
  printf '%s\n' "$result" | grep -vx '__LOADOUT_NVIM_OK__' | grep -v '^[[:space:]]*$' || true
  exit 0
fi

reason=$(printf '%s\n' "$result" | sed -n 's/^__LOADOUT_NVIM_ERR__ //p' | head -1)
[ -n "$reason" ] || reason="headless nvim crashed or timed out"
# Squash the reason to a single line so it stays one table row.
reason=$(printf '%s' "$reason" | tr '\n' ' ')
fail "$reason (rerun; check nvim/lazy)"
