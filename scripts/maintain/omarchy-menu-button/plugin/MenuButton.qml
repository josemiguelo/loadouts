pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Ui

// The menu button as an icon: icons/omarchy.svg (the omarchy font's logo
// glyph as a path) drawn by BarSvgIcon in the bar's foreground colour. A click toggles omarchy.menu (Keystroke, when it is the enabled
// menu), a right click opens a terminal. After it come Keystroke's bar items
// (what a palette provider shows through host.setBarItem), read from the
// running palette like Keystroke's own bar widget does, so this widget takes
// that one's place on the bar.
BarWidget {
  id: root
  moduleName: "josemiguelo.menu-button"

  readonly property var keystroke: {
    var shell = root.bar ? root.bar.shell : null
    var loaders = shell && shell.panelLoaders ? shell.panelLoaders : null
    var loader = loaders ? loaders["evindor.keystroke"] : null
    return loader && loader.item ? loader.item : null
  }
  readonly property var items: root.keystroke && root.keystroke.barList ? root.keystroke.barList : []

  function toggleMenu() {
    if (root.bar) root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
  }
  function openItem(item) {
    if (!root.bar) return
    if (item && item.payload) root.bar.run("omarchy-shell shell summon omarchy.menu " + Util.shellQuote(JSON.stringify(item.payload)))
    else root.toggleMenu()
  }

  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  Row {
    id: layout

    WidgetButton {
      id: button
      bar: root.bar
      hasVisualContent: true
      labelVisible: false
      fixedWidth: root.vertical ? -1 : root.barSize
      fixedHeight: root.vertical ? root.barSize : -1
      onPressed: function(pressedButton) {
        if (!root.bar) return
        if (pressedButton === Qt.RightButton) root.bar.run("xdg-terminal-exec")
        else root.toggleMenu()
      }

      BarSvgIcon {
        anchors.centerIn: parent
        button: button
        source: "icons/omarchy.svg"
      }
    }

    Repeater {
      model: root.items
      delegate: WidgetButton {
        required property var modelData
        bar: root.bar
        visible: !root.vertical && text !== ""
        text: String(modelData.text || "")
        tooltipText: String(modelData.tooltip || "")
        horizontalMargin: 5
        onPressed: function(pressedButton) { root.openItem(modelData) }
      }
    }
  }
}
