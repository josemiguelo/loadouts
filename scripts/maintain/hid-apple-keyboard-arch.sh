#!/bin/sh
# Internal keyboard behaviour on the MacBookPro16,1 (T2) — the Arch/Omarchy
# version of hid-apple-keyboard.sh; same keyboard, same wanted behaviour:
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
# What differs on Omarchy:
#   - Its installer writes this file first, once, as `fnmode=2` (so F-keys on
#     external Apple-like keyboards are always F-keys); it is replaced here.
#   - hid_apple loads from the initramfs (apple-t2.conf puts it in MODULES,
#     and the modconf hook copies modprobe.d in), built by mkinitcpio through
#     Limine: `limine-mkinitcpio` rebuilds it AND the boot entries, which a
#     bare `mkinitcpio -P` would leave stale.
#   - /boot isn't readable unprivileged, so the image's age can't be compared
#     with the file's. The live parameters tell instead: after a boot they are
#     what the initramfs loaded, so a mismatch means the image is stale.
set -eu

CONF=/etc/modprobe.d/hid_apple.conf
PARAMS=/sys/module/hid_apple/parameters
WANT='options hid_apple swap_fn_leftctrl=1
options hid_apple swap_opt_cmd=1'

# fnmode 3 is the module default; it is what the absent conf line yields.
want_param() { [ "$(cat "$PARAMS/$1" 2>/dev/null)" = "$2" ]; }
live_ok() { want_param fnmode 3 && want_param swap_fn_leftctrl 1 && want_param swap_opt_cmd 1; }

case "${1:-install}" in
  check)
    [ "$(cat "$CONF" 2>/dev/null)" = "$WANT" ]
    live_ok
    ;;
  install)
    rebuild=no
    if [ "$(cat "$CONF" 2>/dev/null)" != "$WANT" ]; then
      printf '%s\n' "$WANT" | sudo tee "$CONF" >/dev/null
      rebuild=yes
    fi
    # The image that booted didn't carry the file's values: rebuild it too.
    live_ok || rebuild=yes
    if [ "$rebuild" = yes ]; then
      sudo limine-mkinitcpio
    fi
    # Apply to the already-loaded module so no reboot is needed.
    for pair in fnmode:3 swap_fn_leftctrl:1 swap_opt_cmd:1; do
      p=${pair%:*}; v=${pair#*:}
      want_param "$p" "$v" || echo "$v" | sudo tee "$PARAMS/$p" >/dev/null
    done
    ;;
  *) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
