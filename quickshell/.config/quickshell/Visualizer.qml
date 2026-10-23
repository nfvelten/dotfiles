import QtQuick
import Quickshell
import Quickshell.Io

// Spectrum bars fed by cava. Only runs while visible and `running`; idle bars rest flat.
Item {
    id: viz
    required property QtObject theme
    property bool running: true
    property var levels: []
    implicitHeight: 22
    Process {
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
        running: viz.running && viz.visible
        onRunningChanged: if (!running) viz.levels = []
        stdout: SplitParser { onRead: data => viz.levels = data.split(";").filter(function(v) { return v !== "" }).map(Number) }
    }
    Row {
        anchors.fill: parent; spacing: 2
        Repeater {
            model: 36
            Rectangle {
                required property int index
                width: (viz.width - 35 * 2) / 36; radius: 1
                height: Math.max(2, viz.height * (viz.levels[index] || 0) / 100)
                anchors.bottom: parent.bottom
                color: viz.theme.accent; opacity: 0.35 + 0.65 * (viz.levels[index] || 0) / 100
            }
        }
    }
}
