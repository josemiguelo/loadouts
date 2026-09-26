# Sourced by the Hyprland scripts. hyprctl talks to the instance in
# HYPRLAND_INSTANCE_SIGNATURE, which a shell (or tmux server) that outlived a
# re-login still points at the dead one, and it exits 0 even when it can't
# connect. live_instance prints an instance that answers — the
# environment's, else the newest — or nothing when none does.
live_instance() {
  dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr
  for sig in ${HYPRLAND_INSTANCE_SIGNATURE:-} $(ls -t "$dir" 2>/dev/null); do
    if HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl -j version 2>/dev/null | grep -q '"branch"'; then
      echo "$sig"
      return
    fi
  done
}
