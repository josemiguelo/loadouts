import QtQuick
import QtQuick.Effects
import QtQuick.Window
import qs.Commons
import qs.Ui
import "glyphs.js" as Glyphs

// A bar icon drawn from an SVG in icons/ (white fill), tinted with the
// colour the host's glyph would have had: its activeColor while active,
// its foreground otherwise, so it follows the theme and the transparent bar's
// text colour like the glyph did. Tinting is MultiEffect colorization, as the
// tray does for symbolic icons; colour changes animate like the glyph's.
// `host` is the WidgetButton/BarIconButton the icon stands in for. The SVG
// is `source` when set, else the one glyphs.js maps the host's glyph (its
// text) to; a glyph with no mapping is drawn as the glyph, like the original.
// `share` is the icon's share of the bar's thickness.
Item {
  id: root

  property var host: null
  property string source: ""
  property real share: 0.7
  property color color: host ? (host.active && host.useActiveColor ? host.activeColor : host.foreground) : Color.bar.text

  readonly property string glyph: host ? String(host.text || "") : ""
  readonly property string file: source !== "" ? source : Glyphs.iconFor(glyph)
  readonly property real size: Math.round((host ? host.barSize : Style.bar.sizeHorizontal) * share)

  implicitWidth: size
  implicitHeight: size

  Image {
    id: image
    anchors.centerIn: parent
    width: root.size
    height: root.size
    visible: false
    fillMode: Image.PreserveAspectFit
    smooth: true
    // Rasterised at physical pixels, so it stays sharp on HiDPI.
    sourceSize.width: width * Screen.devicePixelRatio
    sourceSize.height: height * Screen.devicePixelRatio
    source: root.file === "" ? "" : Qt.resolvedUrl(root.file)
  }

  MultiEffect {
    anchors.fill: image
    visible: root.file !== ""
    source: image
    rotation: root.host ? root.host.textRotation : 0
    colorization: 1.0
    colorizationColor: root.color

    Behavior on colorizationColor {
      enabled: !root.host || !root.host.bar || root.host.bar.foregroundAnimationEnabled
      ColorAnimation { duration: 160 }
    }
  }

  // A glyph glyphs.js doesn't know, drawn as BarIconButton draws it.
  OpticalGlyph {
    anchors.fill: parent
    visible: root.file === "" && root.glyph !== ""
    text: root.glyph
    fontFamily: root.host ? root.host.fontFamily : Style.font.family
    fontSize: root.host ? root.host.fontSize : Style.bar.iconFont
    color: root.color
    rotation: root.host ? root.host.textRotation : 0
  }
}
