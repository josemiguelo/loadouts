import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// The tiling layout of the focused workspace, as Hyprland reports it in the
// workspace's tiledLayout, shown as a Nerd Font glyph (the name is in the
// tooltip). A click runs Omarchy's own toggle, the one on SUPER + L.
BarWidget {
  id: root
  moduleName: "josemiguelo.workspace-layout"

  readonly property var workspace: Hyprland.focusedWorkspace
  readonly property string layout: {
    var ipc = workspace ? workspace.lastIpcObject : null
    return ipc && ipc.tiledLayout ? String(ipc.tiledLayout) : ""
  }

  // Material Design glyphs: carousel, dashboard, quilt, fullscreen; any other
  // layout gets a generic window glyph.
  readonly property var glyphs: ({
    scrolling: "\u{F056C}",
    dwindle: "\u{F056E}",
    master: "\u{F0574}",
    monocle: "\u{F0293}"
  })
  readonly property string glyph: layout === "" ? "" : (glyphs[layout] || "\u{F10AC}")

  // A workspace rule changing the layout raises no Hyprland event, so the
  // workspaces are re-read on a short interval; that is a request on
  // Hyprland's socket, not a process.
  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: Hyprland.refreshWorkspaces()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event && event.name ? String(event.name) : ""
      if (name === "workspace" || name === "focusedmon" || name === "configreloaded") Hyprland.refreshWorkspaces()
    }
  }

  Timer {
    id: afterToggle
    interval: 150
    onTriggered: Hyprland.refreshWorkspaces()
  }

  visible: layout !== ""
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    horizontalMargin: 6
    tooltipText: root.workspace ? "Workspace " + root.workspace.name + ": " + root.layout + " (click toggles)" : ""
    onPressed: function() {
      if (!root.bar) return
      root.bar.run("omarchy-hyprland-workspace-layout-toggle")
      afterToggle.restart()
    }
  }
}
