import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// The tiling layout of the focused workspace, as Hyprland reports it in the
// workspace's tiledLayout, shown as an icon drawn by BarSvgIcon in the bar's
// foreground colour (the name is in the tooltip). A click runs Omarchy's own
// toggle, the one on SUPER + L.
BarWidget {
  id: root
  moduleName: "josemiguelo.workspace-layout"

  readonly property var workspace: Hyprland.focusedWorkspace
  readonly property string layout: {
    var ipc = workspace ? workspace.lastIpcObject : null
    return ipc && ipc.tiledLayout ? String(ipc.tiledLayout) : ""
  }

  // Material Design Icons (Apache-2.0) in icons/: carousel, dashboard,
  // quilt, fullscreen; any other layout gets a window.
  readonly property var icons: ({
    scrolling: "view-carousel",
    dwindle: "view-dashboard",
    master: "view-quilt",
    monocle: "fullscreen"
  })
  readonly property string icon: layout === "" ? "" : "icons/" + (icons[layout] || "application-outline") + ".svg"

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
    hasVisualContent: root.icon !== ""
    labelVisible: false
    fixedWidth: root.vertical ? -1 : root.barSize
    fixedHeight: root.vertical ? root.barSize : -1
    tooltipText: root.workspace ? "Workspace " + root.workspace.name + ": " + root.layout + " (click toggles)" : ""
    onPressed: function() {
      if (!root.bar) return
      root.bar.run("omarchy-hyprland-workspace-layout-toggle")
      afterToggle.restart()
    }

    BarSvgIcon {
      anchors.centerIn: parent
      host: button
      source: root.icon
    }
  }
}
