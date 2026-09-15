import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.UPower

Rectangle {
    required property QtObject theme
    required property string time
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
        Row {
            visible: UPower.displayDevice.ready && UPower.displayDevice.isPresent
            spacing: 4
            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 16
                source: Quickshell.iconPath(UPower.displayDevice.iconName)
            }
            Text {
                text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                color: theme.foreground
                font.pixelSize: 13
            }
        }
    }

}
