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
// `host` is the WidgetButton/BarIconButton the icon stands in for. Its text's
// last character is the glyph and anything before it a label ("86% 󰂁"), drawn
// as text ahead of the icon in the host's font. The SVG is `source` when set,
// else the one glyphs.js maps the glyph to; with no mapping the host's text is
// drawn as the host would draw it. `share` is the icon's share of the bar's
// thickness.
Item {
  id: root

  property var host: null
  property string source: ""
  property real share: 0.7
  property color color: host ? (host.active && host.useActiveColor ? host.activeColor : host.foreground) : Color.bar.text

  readonly property string text: host ? String(host.text || "").replace(/\s+$/, "") : ""
  // The last character, a surrogate pair for the Nerd Font md glyphs.
  readonly property int glyphLength: {
    var last = text.length > 1 ? text.charCodeAt(text.length - 1) : 0
    return text === "" ? 0 : (last >= 0xDC00 && last <= 0xDFFF ? 2 : 1)
  }
  readonly property string glyph: text.slice(text.length - glyphLength)
  readonly property string label: text.slice(0, text.length - glyphLength).replace(/\s+$/, "")
  readonly property string file: source !== "" ? source : Glyphs.iconFor(glyph)
  readonly property real size: Math.round((host ? host.barSize : Style.bar.sizeHorizontal) * share)
  readonly property string fontFamily: host ? host.fontFamily : Style.font.family
  readonly property real fontSize: host ? host.fontSize : Style.bar.iconFont

  implicitWidth: row.implicitWidth
  implicitHeight: size

  Row {
    id: row
    anchors.centerIn: parent
    visible: root.file !== ""
    spacing: label.visible ? Math.round(root.fontSize * 0.3) : 0

    Text {
      id: label
      anchors.verticalCenter: parent.verticalCenter
      visible: root.label !== ""
      textFormat: Text.PlainText
      text: root.label
      color: root.color
      font.family: root.fontFamily
      font.pixelSize: Math.round(root.fontSize)
      renderType: Text.NativeRendering
    }

    Item {
      width: root.size
      height: root.size

      Image {
        id: image
        anchors.fill: parent
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
        source: image
        rotation: root.host ? root.host.textRotation : 0
        colorization: 1.0
        colorizationColor: root.color

        Behavior on colorizationColor {
          enabled: !root.host || !root.host.bar || root.host.bar.foregroundAnimationEnabled
          ColorAnimation { duration: 160 }
        }
      }
    }
  }

  // A glyph glyphs.js doesn't know: the host's text, drawn as BarIconButton
  // draws it.
  OpticalGlyph {
    anchors.fill: parent
    visible: root.file === "" && root.text !== ""
    text: root.text
    fontFamily: root.fontFamily
    fontSize: root.fontSize
    color: root.color
    rotation: root.host ? root.host.textRotation : 0
  }
}
