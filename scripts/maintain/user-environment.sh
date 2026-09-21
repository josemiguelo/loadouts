#!/bin/sh
# The systemd user manager's environment reflects ~/.config/environment.d.
# The manager reads those files only when it starts or on daemon-reload, so a
# file the dotfiles just wrote is invisible to the session (and everything
# it launches) until one of those happens — and a logout does not restart
# the manager while anything (a tmux server, say) keeps it alive.
# Modes: `check` (every KEY=VALUE assignment present in the manager env?) /
# `install` (daemon-reload, then the same test).
set -eu

ENV_D="$HOME/.config/environment.d"

wanted() {
  [ -d "$ENV_D" ] || return 0
  # Plain KEY=VALUE lines; comments and blank lines are not assignments.
  cat "$ENV_D"/*.conf 2>/dev/null | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' || true
}

missing() {
  current=$(systemctl --user show-environment)
  wanted | while IFS= read -r line; do
    printf '%s\n' "$current" | grep -qxF "$line" || { echo "$line"; }
  done
}

case "${1:-install}" in
  check)
    [ -z "$(missing)" ]
    ;;
  install)
    if [ -n "$(missing)" ]; then
      systemctl --user daemon-reload
    fi
    left=$(missing)
    [ -z "$left" ] || { echo "still not in the user manager environment:" >&2; echo "$left" >&2; exit 1; }
    ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
