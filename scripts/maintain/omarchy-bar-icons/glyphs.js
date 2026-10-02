.pragma library

// The Nerd Font glyph a widget picks, by codepoint (hex, upper case), to the
// SVG in icons/ that BarSvgIcon draws in its place. Nerd Font's md range is
// Material Design Icons' own codepoints, so those map to the icon of the same
// codepoint; glyphs from other sets map to their closest MDI icon.
var icons = {
  "EEE8": "volume-mute",
  "F0079": "battery",
  "F007A": "battery-10",
  "F007B": "battery-20",
  "F007C": "battery-30",
  "F007D": "battery-40",
  "F007E": "battery-50",
  "F007F": "battery-60",
  "F0080": "battery-70",
  "F0081": "battery-80",
  "F0082": "battery-90",
  "F0085": "battery-charging-100",
  "F0086": "battery-charging-20",
  "F0087": "battery-charging-30",
  "F0088": "battery-charging-40",
  "F0089": "battery-charging-60",
  "F008A": "battery-charging-80",
  "F008B": "battery-charging-90",
  "F00AF": "bluetooth",
  "F00B1": "bluetooth-connect",
  "F00B2": "bluetooth-off",
  "F0200": "ethernet",
  "F026": "volume-low",
  "F027": "volume-medium",
  "F028": "volume-high",
  "F02CB": "headphones",
  "F0379": "monitor",
  "F037A": "monitor-multiple",
  "F089C": "battery-charging-10",
  "F089D": "battery-charging-50",
  "F089E": "battery-charging-70",
  "F091F": "wifi-strength-1",
  "F0922": "wifi-strength-2",
  "F0925": "wifi-strength-3",
  "F0928": "wifi-strength-4",
  "F092E": "wifi-strength-off-outline",
  "F092F": "wifi-strength-outline"
}

// The icon file for a glyph string, or "" when it has none.
function iconFor(glyph) {
  if (!glyph) return ""
  var cp = glyph.codePointAt(0)
  if (cp === undefined) return ""
  var name = icons[cp.toString(16).toUpperCase()]
  return name ? "icons/" + name + ".svg" : ""
}
