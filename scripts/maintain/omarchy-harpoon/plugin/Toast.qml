// A card low on the screen naming the workspace you just landed
// on, whatever moved you there (a harpoon key, a picked window, SUPER+number,
// a swipe): it follows Hyprland's focused workspace. Special workspaces (the
// scratchpad, overlays) show none. Built like Omarchy's OSD (osd/Osd.qml): a
// click-through overlay layer that hides itself after `duration` ms.
//   omarchy-shell -q harpoonToast show '{"workspace":"2"}'   shows it by hand
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root

  property bool opened: false
  property string workspace: ""
  property int duration: 1200
  // The workspace focused when the plugin loaded, or last shown: a card only
  // for a change, never for the one you were already on.
  property string last: ""
  Component.onCompleted: last = Hyprland.focusedWorkspace ? String(Hyprland.focusedWorkspace.name) : ""

  readonly property int pad: Style.space(28)
  readonly property int textSize: Math.round(Style.font.displayLarge * 1.6)

  function showWorkspace(name, ms) {
    workspace = String(name)
    duration = ms
    opened = true
    if (duration > 0) hideTimer.restart()
    else hideTimer.stop()
  }

  function show(payloadJson) {
    try {
      var p = JSON.parse(payloadJson || "{}")
      if (!p.workspace) return
      showWorkspace(p.workspace, p.duration === undefined ? 1200 : Math.max(0, parseInt(p.duration, 10) || 0))
    } catch (e) {}
  }

  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() {
      var ws = Hyprland.focusedWorkspace
      if (!ws) return
      var name = String(ws.name)
      if (name === root.last || name.indexOf("special:") === 0) return
      root.last = name
      root.showWorkspace(name, 1200)
    }
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
    function state(): string {
      return JSON.stringify({ opened: root.opened, workspace: root.workspace, last: root.last,
                              focused: Hyprland.focusedWorkspace ? String(Hyprland.focusedWorkspace.name) : null })
    }
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
      // Low on the screen, out of the way: its bottom edge 20% of the
      // screen's height above the bottom.
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Math.round(parent.height * 0.2)
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
