import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: bar
    required property QtObject theme
    required property string time
    signal menuRequested()
    signal controlsRequested(int column)

    anchors { top: true; left: true; right: true }
    margins { top: 6; left: 8; right: 8 }
    implicitHeight: 34
    color: "transparent"
    exclusiveZone: implicitHeight
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "yerba-bar"

    StatusStrip {
        anchors.fill: parent
        theme: bar.theme
        time: bar.time
        onControlsRequested: function(column) { bar.controlsRequested(column) }
    }
}
