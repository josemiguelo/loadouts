#!/bin/sh
# omarchy-default-browser hardcodes Arch's desktop id (firefox.desktop); Fedora's
# firefox rpm ships org.mozilla.firefox.desktop, so the omarchy command fails
# silently. A hidden alias entry under the name omarchy expects makes every
# omarchy browser command (default/launch/query) work with the rpm.
# Modes: `check` (firefox already the default?) / `install` (default).
set -eu

WANT="firefox"
ALIAS="$HOME/.local/share/applications/firefox.desktop"

current() {
  omarchy default browser
}

write_alias() {
  mkdir -p "$(dirname "$ALIAS")"
  cat > "$ALIAS" <<'DESKTOP'
[Desktop Entry]
# Alias for Fedora's org.mozilla.firefox.desktop: Omarchy's browser tooling
# expects Arch's desktop id "firefox.desktop". Hidden so the launcher doesn't
# show Firefox twice. Managed by loadout (scripts/maintain/omarchy-default-browser.sh).
Type=Application
Name=Firefox
Exec=firefox %u
Icon=firefox
Terminal=false
NoDisplay=true
StartupWMClass=firefox
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
DESKTOP
  update-desktop-database "$(dirname "$ALIAS")" 2>/dev/null || true
}

case "${1:-install}" in
  check)
    [ -f "$ALIAS" ] && cur=$(current) && [ "$cur" = "$WANT" ]
    ;;
  install)
    write_alias
    omarchy default browser "$WANT"
    ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
