#!/bin/sh
# Internal keyboard behaviour on the MacBookPro16,1 (T2).
#
#   swap_fn_leftctrl=1  bottom-left corner key acts as Ctrl; the key labelled
#                       "control" becomes Fn (and so toggles the touchbar
#                       between media keys and F1-F12, via hid_appletb_kbd).
#   swap_opt_cmd=1      Alt/Super swapped, PC layout.
#   fnmode              deliberately NOT set -> module default 3 (auto), which
#                       resolves to 4 for this keyboard (APPLE_DISABLE_FKEYS on
#                       WELLSPRINGT2_J152F). That leaves the non-existent F-row
#                       alone but keeps Fn+arrows = Home/End/PgUp/PgDn and
#                       Fn+backspace = Delete.
#
# The live parameters matter as much as the file: hid_apple is loaded from the
# initramfs (the T2 keyboard comes up over t2bce_vhci in early boot), so a
# stale initramfs keeps old values alive across a reboot and modprobe.d is
# never consulted again. check therefore verifies BOTH, and install
# regenerates the initramfs whenever the conf is newer than it.
set -eu

CONF=/etc/modprobe.d/hid_apple.conf
PARAMS=/sys/module/hid_apple/parameters
WANT='options hid_apple swap_fn_leftctrl=1
options hid_apple swap_opt_cmd=1'

# fnmode 3 is the module default; it is what the absent conf line yields.
want_param() { [ "$(cat "$PARAMS/$1" 2>/dev/null)" = "$2" ]; }

case "${1:-install}" in
  check)
    [ "$(cat "$CONF" 2>/dev/null)" = "$WANT" ]
    want_param fnmode 3
    want_param swap_fn_leftctrl 1
    want_param swap_opt_cmd 1
    ;;
  install)
    if [ "$(cat "$CONF" 2>/dev/null)" != "$WANT" ]; then
      printf '%s\n' "$WANT" | sudo tee "$CONF" >/dev/null
    fi
    if [ "$CONF" -nt "/boot/initramfs-$(uname -r).img" ]; then
      sudo dracut -f
    fi
    # Apply to the already-loaded module so no reboot is needed.
    for pair in fnmode:3 swap_fn_leftctrl:1 swap_opt_cmd:1; do
      p=${pair%:*}; v=${pair#*:}
      want_param "$p" "$v" || echo "$v" | sudo tee "$PARAMS/$p" >/dev/null
    done
    ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
