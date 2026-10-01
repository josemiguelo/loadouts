// A card in the middle of the screen naming the workspace a harpoon jump
// moved to. Built like Omarchy's OSD (osd/Osd.qml): a click-through overlay
// layer that hides itself after `duration` ms.
//   omarchy-shell -q harpoonToast show '{"workspace":"2"}'
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root

  property bool opened: false
  property string workspace: ""
  property int duration: 1200

  readonly property int pad: Style.space(28)
  readonly property int textSize: Math.round(Style.font.displayLarge * 1.6)

  function show(payloadJson) {
    try {
      var p = JSON.parse(payloadJson || "{}")
      if (!p.workspace) return
      workspace = String(p.workspace)
      duration = p.duration === undefined ? 1200 : Math.max(0, parseInt(p.duration, 10) || 0)
      opened = true
      if (duration > 0) hideTimer.restart()
      else hideTimer.stop()
    } catch (e) {}
  }

  Timer {
    id: hideTimer
    interval: root.duration
    onTriggered: root.opened = false
  }

  IpcHandler {
    target: "harpoonToast"
    function show(payloadJson: string): string { root.show(payloadJson); return "ok" }
    function close(): string { root.opened = false; return "ok" }
    function ping(): string { return "ok" }
  }

  PanelWindow {
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "harpoon-toast"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Never blocks clicks to the windows below.
    mask: Region {}

    BorderSurface {
      id: card
      width: card.borderLeft + root.pad + label.implicitWidth + root.pad + card.borderRight
      height: card.borderTop + root.pad + label.implicitHeight + root.pad + card.borderBottom
      anchors.centerIn: parent
      color: Util.alpha(Color.background, 0.97)
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
      radius: Style.cornerRadius

      Text {
        id: label
        x: card.borderLeft + root.pad
        y: card.borderTop + root.pad
        textFormat: Text.PlainText
        text: "Workspace " + root.workspace
        font.family: Style.font.family
        font.bold: true
        font.pixelSize: root.textSize
        color: Color.accent
      }
    }
  }
}
