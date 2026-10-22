import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Networking

Rectangle {
    required property QtObject theme
    required property string time
    signal controlsRequested(int column)
    property bool dnd: false
    property bool meeting: false
    property int unread: 0
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property bool micMuted: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Pipewire.defaultAudioSource.audio.muted : false
    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool wiredUp: Networking.devices.values.some(function(d) { return d.type === DeviceType.Wired && d.connected })
    readonly property bool wifiUp: Networking.devices.values.some(function(d) { return d.type === DeviceType.Wifi && d.connected })
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
            model: (meeting ? [{icon: "󰕧", column: -1}] : []).concat(micMuted ? [{icon: "󰍭", column: 0}] : []).concat(dnd ? [{icon: "󰂛", column: -1}] : unread > 0 ? [{icon: "󰂚 " + unread, column: -1}] : []).concat([
                {icon: wiredUp ? "󰈀" : !Networking.wifiEnabled ? "󰤮" : wifiUp ? "󰤨" : "󰤯", column: 2},
                {icon: sinkAudio && sinkAudio.muted ? "󰖁" : "󰕾", column: 0},
                {icon: !adapter || !adapter.enabled ? "󰂲" : Bluetooth.devices.values.some(function(d) { return d.connected }) ? "󰂱" : "", column: 1}
            ])
            delegate: Text {
                text: modelData.icon
                color: theme.foreground
                font.pixelSize: 13
                MouseArea {
                    anchors.fill: parent
                    enabled: modelData.column >= 0
                    onClicked: controlsRequested(modelData.column)
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
