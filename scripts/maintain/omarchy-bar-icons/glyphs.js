.pragma library

// The Nerd Font glyph a widget picks, by codepoint (hex, upper case), to the
// SVG in icons/ that BarSvgIcon draws in its place. Nerd Font's md range is
// Material Design Icons' own codepoints, so those map to the icon of the same
// codepoint; glyphs from other sets map to their closest MDI icon.
var icons = {
  "F00AF": "bluetooth",
  "F00B1": "bluetooth-connect",
  "F00B2": "bluetooth-off",
  "F0379": "monitor",
  "F037A": "monitor-multiple"
}

// The icon file for a glyph string, or "" when it has none.
function iconFor(glyph) {
  if (!glyph) return ""
  var cp = glyph.codePointAt(0)
  if (cp === undefined) return ""
  var name = icons[cp.toString(16).toUpperCase()]
  return name ? "icons/" + name + ".svg" : ""
}
