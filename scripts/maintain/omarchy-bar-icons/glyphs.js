.pragma library

// The Nerd Font glyph a widget picks, by codepoint (hex, upper case), to the
// SVG in icons/ that BarSvgIcon draws in its place. Nerd Font's md range is
// Material Design Icons' own codepoints, so those map to the icon of the same
// codepoint; glyphs from other sets map to their closest MDI icon.
var icons = {
  "F00AF": "bluetooth",
  "F00B1": "bluetooth-connect",
  "F00B2": "bluetooth-off",
  "F0200": "ethernet",
  "F0379": "monitor",
  "F037A": "monitor-multiple",
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
