#!/bin/sh
# Voxtype dictation, set up the native way: Omarchy's own installer
# (omarchy-voxtype-install) copies Omarchy's voxtype config, downloads the
# speech model (~150MB), enables GPU inference when Vulkan is there, installs
# the systemd user service, and reloads Hyprland and the shell. Then F9 is
# hold-to-dictate, Super+Ctrl+X toggles.
#
# The installer asks first (a gum confirm), so it needs a terminal: run it
# through `loadout setup-new-machine` or `loadout run omarchy-dictation`. From
# the home screen's pane nothing can answer, the installer does nothing, and
# the check stays pending.
# Modes: `check` / `install` (default).
set -eu

ready() {
  command -v voxtype >/dev/null 2>&1 &&
    [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/voxtype/config.toml" ] &&
    systemctl --user -q is-enabled voxtype.service 2>/dev/null
}

case "${1:-install}" in
check)
  ready
  ;;
install)
  # Judged by the result, not the installer's exit code: it ends by
  # restarting the Omarchy shell and at once sending a notification through
  # it, and when the shell isn't back yet that last call fails ("The name is
  # not activatable") with everything already in place.
  omarchy-voxtype-install || echo "(omarchy-voxtype-install exited $?)" >&2
  ready || { echo "dictation isn't set up — the installer was declined or had no terminal to ask in" >&2; exit 1; }
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
