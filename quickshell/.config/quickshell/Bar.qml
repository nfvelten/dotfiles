import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    required property QtObject theme
    required property string time
    signal menuRequested()

    anchors { top: true; left: true; right: true }
    margins { top: 6; left: 8; right: 8 }
    implicitHeight: 34
    color: "transparent"
    exclusiveZone: implicitHeight
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "yerba-bar"

    Rectangle {
        anchors.fill: parent
        radius: theme.radius
        color: theme.background
        border.color: theme.border
        border.width: 1

        Row {
            anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
            spacing: 9
            Repeater {
                model: 5
                delegate: Text {
                    required property int index
                    text: index + 1
                    color: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === index + 1 ? theme.accent : theme.foreground
                    font.pixelSize: 13
                    MouseArea { anchors.fill: parent; onClicked: Hyprland.dispatch("workspace " + (index + 1)) }
                }
            }
        }
        Text { anchors.centerIn: parent; text: time; color: theme.foreground; font.pixelSize: 13 }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Repeater {
                model: [
                    {icon: "󰤨", app: "nmtui"},
                    {icon: "󰕾", app: "wiremix"},
                    {icon: "", app: "bluetui"}
                ]
                delegate: Text {
                    text: modelData.icon
                    color: theme.foreground
                    font.pixelSize: 13
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Quickshell.execDetached(["ghostty", "-e", modelData.app])
                    }
                }
            }
        }

    }
}
