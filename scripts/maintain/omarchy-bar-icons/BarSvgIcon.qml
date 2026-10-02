import QtQuick
import QtQuick.Effects
import QtQuick.Window
import qs.Commons

// A bar icon drawn from an SVG in icons/ (white fill), tinted with the
// colour the button's glyph would have had: its activeColor while active,
// its foreground otherwise, so it follows the theme and the transparent bar's
// text colour like the glyph did. Tinting is MultiEffect colorization, as the
// tray does for symbolic icons; colour changes animate like the glyph's.
// `button` is the WidgetButton/BarIconButton the icon stands in for; `scale`
// is the icon's share of the bar's thickness.
Item {
  id: root

  property var button: null
  property string source: ""
  property real scale: 0.7
  property color color: button ? (button.active && button.useActiveColor ? button.activeColor : button.foreground) : Color.bar.text

  readonly property real size: Math.round((button ? button.barSize : Style.bar.sizeHorizontal) * scale)

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
    source: root.source === "" ? "" : Qt.resolvedUrl(root.source)
  }

  MultiEffect {
    anchors.fill: image
    source: image
    rotation: root.button ? root.button.textRotation : 0
    colorization: 1.0
    colorizationColor: root.color

    Behavior on colorizationColor {
      enabled: !root.button || !root.button.bar || root.button.bar.foregroundAnimationEnabled
      ColorAnimation { duration: 160 }
    }
  }
}
