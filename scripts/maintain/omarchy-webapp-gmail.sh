#!/bin/sh
# Gmail as an Omarchy web app (its own app window, like HEY) and as the
# mailto handler — the way Omarchy wires HEY: a handler command in the
# launcher's Exec (omarchy-webapp-handler-hey there), the launcher declaring
# x-scheme-handler/mailto, and xdg-mime making it the default. The handler
# is named like Omarchy's so Omarchy's own web-app tools list and remove it.
# Modes: `check` / `install` (default).
set -eu

HANDLER=$HOME/.local/bin/omarchy-webapp-handler-gmail
DESKTOP=$HOME/.local/share/applications/Gmail.desktop
ICON=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/gmail.png

handler_body() {
  cat <<'HANDLER_EOF'
#!/bin/sh
# Managed by loadout (omarchy-webapp-gmail): open Gmail, turning a mailto:
# link into Gmail's compose — what omarchy-webapp-handler-hey does for HEY.
url=${1:-}
web=https://mail.google.com/
case $url in
mailto:*) web="https://mail.google.com/mail/?extsrc=mailto&url=$(jq -rn --arg u "$url" '$u | @uri')" ;;
esac
exec omarchy-launch-webapp "$web"
HANDLER_EOF
}

ready() {
  [ -f "$HANDLER" ] && [ "$(cat "$HANDLER")" = "$(handler_body)" ] && [ -x "$HANDLER" ] &&
    grep -qx 'Exec=omarchy-webapp-handler-gmail %u' "$DESKTOP" 2>/dev/null &&
    grep -q '^MimeType=.*x-scheme-handler/mailto' "$DESKTOP" &&
    [ "$(xdg-mime query default x-scheme-handler/mailto)" = Gmail.desktop ]
}

case "${1:-install}" in
check)
  ready
  ;;
install)
  mkdir -p "$(dirname "$HANDLER")"
  handler_body > "$HANDLER"
  chmod +x "$HANDLER"
  omarchy-webapp-install Gmail https://mail.google.com/ "$ICON" "omarchy-webapp-handler-gmail %u" "x-scheme-handler/mailto;"
  xdg-mime default Gmail.desktop x-scheme-handler/mailto
  ready || { echo "Gmail web app or mailto default not in place after install" >&2; exit 1; }
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
