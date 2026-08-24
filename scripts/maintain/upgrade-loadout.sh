#!/bin/sh
# Keep the loadout binary at (or above) the repo's declared floor
# (`min-tool-version` in manifest.toml). Local-only check — no network —
# so it can run on every `status` refresh. Bump the floor in a commit to
# roll the fleet forward; each machine's next status flags this pending.
# Modes: `check` / `install` (default). cwd is the repo root (loadout
# contract), so manifest.toml is read relative to it.
set -eu
export PATH="$HOME/.local/bin:$PATH"

MODE="${1:-install}"
case "$MODE" in
check | install) ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac

floor=$(awk -F'"' '/^min-tool-version/ {print $2}' manifest.toml)
[ -n "$floor" ] || { echo "no min-tool-version in manifest.toml" >&2; exit 2; }
current=$(loadout --help 2>/dev/null | grep -o 'v[0-9][0-9.]*' | head -1 | tr -d v || true)

# current >= floor, numerically per dotted field (portable: no sort -V on macOS)
at_floor() {
  awk -v a="${1:-0}" -v b="$2" 'BEGIN {
    n = split(a, x, "."); m = split(b, y, "."); k = (n > m ? n : m)
    for (i = 1; i <= k; i++) {
      if (x[i] + 0 > y[i] + 0) exit 0
      if (x[i] + 0 < y[i] + 0) exit 1
    }
    exit 0
  }'
}

if at_floor "$current" "$floor"; then
  exit 0
fi

if [ "$MODE" = "check" ]; then
  echo "missing: loadout ${current:-none} < required $floor"
  exit 1
fi

echo "upgrading loadout ${current:-none} -> latest (floor $floor)"
curl -fsSL https://raw.githubusercontent.com/josemiguelo/loadout/master/install.sh | sh
