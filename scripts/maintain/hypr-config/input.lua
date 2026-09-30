-- Natural (inverse) touchpad scrolling.
hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
    },
  },
})

-- The same for the Logitech MX Master 3 (Bluetooth), only that mouse: the
-- Keychron keyboard also shows up as a mouse and keeps normal scrolling.
-- Name from `hyprctl devices`.
hl.device({ name = "logitech-wireless-mouse-mx-master-3-1", natural_scroll = true })
