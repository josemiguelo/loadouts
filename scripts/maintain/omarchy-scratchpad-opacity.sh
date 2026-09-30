#!/bin/sh
# Kitty windows in the scratchpad (SUPER+S) less see-through than kitty's
# background_opacity, while every other kitty window keeps it. A Hyprland
# window rule can't do it: the compositor caps a window's opacity at 1, so a
# rule only makes windows more transparent — 1.12 and 3.0 looked the same
# as 1.0 on screen, tried live. Kitty has to repaint itself instead: a
# listener in ~/.config/hypr/hyprland.lua (where Omarchy puts personal
# additions) runs `kitten @ set-background-opacity` over the window's
# per-process socket (listen_on, from the dotfiles kitty.conf) when a kitty
# window moves into the scratchpad or opens there, and back to
# background_opacity when it moves out. Kitty only accepts that with
# dynamic_background_opacity on, which the dotfiles kitty.conf sets for this
# machine; kitty reads it at startup, so kitties already running stay put.
# The check compares the block's text: an event listener leaves nothing
# hypr-option.lua can list, unlike a window rule. The block is written from
# kitty.conf's background_opacity, so it drifts (and install rewrites it)
# when that changes. Install rewrites the block between its markers.
#
# Omarchy reloads every kitty's config (SIGUSR1) on a theme change
# (omarchy-restart-terminal), a font change (omarchy-font-set) and a text size
# change (omarchy-display-text-size), which puts scratchpad windows back at
# background_opacity. `reapply` sends the opacity again to the kitty windows in
# the scratchpad — now and a second later, since kitty finishes reloading on
# its own schedule — and runs from Omarchy's theme-set and font-set hooks
# (both run after the reload) and from a wrapper for omarchy-display-text-size
# in the directory omarchy-command-overrides puts first, since that one has no
# hook.
# usage: omarchy-scratchpad-opacity.sh [check|reapply] <opacity>
set -eu

MODE=install
case "${1:-}" in check | reapply) MODE=$1; shift ;; esac
INSIDE=${1:?usage: $0 [check|reapply] <opacity>}

CONF=$HOME/.config/hypr/hyprland.lua
KITTY=$HOME/.config/kitty/kitty.conf
HERE="$(cd "$(dirname "$0")" && pwd)"
SELF=$HERE/omarchy-scratchpad-opacity.sh
PROBE=$HERE/hypr-option.lua
. "$HERE/hypr-live.sh"
. "$HERE/omarchy-overrides-lib.sh"
HOOKS="$HOME/.config/omarchy/hooks/theme-set.d/scratchpad-opacity $HOME/.config/omarchy/hooks/font-set.d/scratchpad-opacity"
TEXT_SIZE=omarchy-display-text-size
WRAPPER=$OVERRIDES_DIR/$TEXT_SIZE
BEGIN="-- >>> Managed by loadout (omarchy-scratchpad-opacity)"
END="-- <<< Managed by loadout (omarchy-scratchpad-opacity)"

# kitty.conf's last value for an option, or nothing.
kitty_option() {
  [ -f "$KITTY" ] || return 0
  awk -v k="$1" '$1 == k { v = $2 } END { if (v != "") print v }' "$KITTY"
}

# Kitty's own default when kitty.conf leaves it out.
OUTSIDE=$(kitty_option background_opacity)
OUTSIDE=${OUTSIDE:-1.0}

dynamic() {
  [ "$(kitty_option dynamic_background_opacity)" = yes ]
}

block() {
  cat <<EOF
$BEGIN
-- Kitty windows in the scratchpad at $INSIDE opacity, the rest at kitty.conf's
-- $OUTSIDE. Hyprland caps a window's opacity at 1, so kitty repaints itself
-- over its socket (scripts/maintain/omarchy-scratchpad-opacity.sh).
local scratchpad_kitty_opacity = { inside = $INSIDE, outside = $OUTSIDE }

local function set_kitty_opacity(window, opacity)
  if window.class ~= "kitty" then return end
  -- A window opened straight into the scratchpad may not be listening yet.
  local socket = os.getenv("XDG_RUNTIME_DIR") .. "/omarchy-kitty-" .. window.pid
  hl.exec_cmd(string.format(
    "for _ in \$(seq 20); do [ -S %s ] && break; sleep 0.1; done; kitten @ --to unix:%s set-background-opacity %s",
    o.shell_quote(socket), o.shell_quote(socket), opacity
  ))
end

local function on_workspace(window, workspace)
  local inside = workspace and workspace.name == "special:scratchpad"
  set_kitty_opacity(window, inside and scratchpad_kitty_opacity.inside or scratchpad_kitty_opacity.outside)
end

hl.on("window.move_to_workspace", on_workspace)
hl.on("window.open", function(window)
  if window.workspace and window.workspace.name == "special:scratchpad" then on_workspace(window, window.workspace) end
end)
$END
EOF
}

hook_text() {
  cat <<EOF
# Managed by loadout (omarchy-scratchpad-opacity): Omarchy just reloaded every
# kitty's config, which puts scratchpad windows back at background_opacity.
sh '$SELF' reapply $INSIDE
EOF
}

wrapper_text() {
  cat <<EOF
#!/bin/bash
# Managed by loadout (omarchy-scratchpad-opacity): after Omarchy's text size
# change reloads every kitty's config, send the scratchpad opacity again.
# Everything else is Omarchy's.
"$OMARCHY_BIN/$TEXT_SIZE" "\$@"
status=\$?
sh '$SELF' reapply $INSIDE
exit \$status
EOF
}

# Send the opacity to every kitty window in the scratchpad.
send_to_scratchpad() {
  sig=$(live_instance)
  [ -n "$sig" ] || return 0
  runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
  HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl clients -j |
    jq -r '.[] | select(.class == "kitty" and .workspace.name == "special:scratchpad") | .pid' |
    while IFS= read -r pid; do
      socket=$runtime/omarchy-kitty-$pid
      [ -S "$socket" ] && kitten @ --to "unix:$socket" set-background-opacity "$INSIDE" >/dev/null 2>&1
    done
  return 0
}

extras_ready() {
  for hook in $HOOKS; do
    [ -f "$hook" ] && [ "$(cat "$hook")" = "$(hook_text)" ] || return 1
  done
  [ -x "$WRAPPER" ] && [ "$(cat "$WRAPPER")" = "$(wrapper_text)" ] && override_active "$TEXT_SIZE"
}

current() {
  [ -f "$CONF" ] || return 0
  awk -v b="$BEGIN" -v e="$END" '$0 == b { keep = 1 } keep { print } $0 == e { keep = 0 }' "$CONF"
}

case "$MODE" in
check)
  dynamic && [ "$(current)" = "$(block)" ] && extras_ready
  ;;
reapply)
  send_to_scratchpad
  (sleep 1; send_to_scratchpad) >/dev/null 2>&1 &
  ;;
install)
  dynamic || { echo "$KITTY doesn't set dynamic_background_opacity yes (the dotfiles kitty.conf does, for this machine): apply the dotfiles first" >&2; exit 1; }
  rest=$(awk -v b="$BEGIN" -v e="$END" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' "$CONF")
  { printf '%s\n\n' "$rest"; block; } > "$CONF"
  for hook in $HOOKS; do
    mkdir -p "$(dirname "$hook")"
    hook_text > "$hook"
  done
  mkdir -p "$OVERRIDES_DIR"
  wrapper_text > "$WRAPPER"
  chmod 755 "$WRAPPER"
  extras_ready || { echo "hooks or $WRAPPER not in place after install (is omarchy-command-overrides installed?)" >&2; exit 1; }
  sig=$(live_instance)
  if [ -n "$sig" ]; then
    HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl -q reload
    errors=$(HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl configerrors | grep -v '^[[:space:]]*$' || true)
    [ -z "$errors" ] || { echo "Hyprland reports config errors after the reload: $errors" >&2; exit 1; }
    echo "Applies to kitty windows started from now on."
  else
    echo "Hyprland isn't reachable from here; applies at the next login."
  fi
  ;;
esac
