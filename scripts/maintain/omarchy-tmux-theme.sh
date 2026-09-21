#!/bin/sh
# omarchy-theme-set-tmux runs on every `omarchy theme set` and pushes the
# omarchy theme's colours into the live tmux server: window-style,
# window-active-style and cursor-colour globally, plus OSC 10/11/4 (fg, bg,
# palette) into every pane alive at the time. tmux here follows kitty's own
# palette instead, so afterwards pane content stops matching the status line
# and kitty's tabs, goes opaque (an explicit bg defeats background_opacity),
# and panes opened later disagree with older ones. The dotfiles pin the
# globals; only a running server can be observed and reset, so no server
# passes. Modes: `check` (server untouched?) / `install` (reset it).
set -eu

tmux_running() {
  tmux list-sessions >/dev/null 2>&1
}

globals_clean() {
  [ "$(tmux show -gv window-style)" = default ] &&
  [ "$(tmux show -gv window-active-style)" = default ] &&
  [ "$(tmux show -gv cursor-colour)" = none ]
}

panes_clean() {
  ! tmux list-panes -a -F '#{pane_bg} #{pane_fg}' | grep -qv '^default default$'
}

reset_globals() {
  tmux set -g window-style default
  tmux set -g window-active-style default
  tmux set -gu cursor-colour
}

# OSC 110/111/104 hand a pane's fg, bg and palette back to the terminal.
reset_panes() {
  tmux list-panes -a -F '#{pane_tty}' | sort -u | while IFS= read -r tty; do
    printf '\033]110\a\033]111\a\033]104\a' > "$tty" 2>/dev/null || true
  done
  tmux list-clients -F '#{client_name}' | while IFS= read -r client; do
    tmux refresh-client -t "$client" 2>/dev/null || true
  done
}

case "${1:-install}" in
  check)
    tmux_running || exit 0
    globals_clean && panes_clean
    ;;
  install)
    tmux_running || exit 0
    reset_globals
    reset_panes
    ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
