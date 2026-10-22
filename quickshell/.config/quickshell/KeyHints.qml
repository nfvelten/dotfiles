import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: popup
    required property QtObject theme
    required property bool shown
    required property string time
    required property bool statusVisible

    visible: shown
    anchors { bottom: true; left: true }
    margins { bottom: 20; left: 18 }
    implicitWidth: 430
    implicitHeight: statusVisible ? 198 : 158
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "yerba-super-hints"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    StatusStrip {
        id: quickStatus
        visible: popup.statusVisible
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34
        theme: popup.theme
        time: popup.time
        onControlsRequested: function(column) {}
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: popup.statusVisible ? 42 : 0
        radius: 8
        color: popup.theme.background
        border.color: popup.theme.border
        border.width: 1
        opacity: 0.98

        ColumnLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: 12
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.bottomMargin: 12
            spacing: 4
            Text {
                text: "Super shortcuts"
                color: popup.theme.foreground
                font.pixelSize: 12
                font.bold: true
                Layout.fillWidth: true
            }
            GridLayout {
                columns: 2
                columnSpacing: 22
                rowSpacing: 4
                Layout.fillWidth: true
                Repeater {
                model: [
                    ["Space", "Dock"],
                    ["C", "Tmux"],
                    ["Shift + O", "Daily note"],
                    ["Shift + M", "Media"],
                    ["H", "Key reference"],
                    ["B", "Browser"]
                ]
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 190
                    spacing: 8
                    Rectangle {
                        implicitWidth: keyText.implicitWidth + 12
                        implicitHeight: 20
                        radius: 4
                        color: Qt.alpha(popup.theme.accent, 0.16)
                        border.color: Qt.alpha(popup.theme.accent, 0.42)
                        Text { id: keyText; anchors.centerIn: parent; text: modelData[0]; color: popup.theme.accent; font.family: "monospace"; font.pixelSize: 10; wrapMode: Text.NoWrap }
                    }
                    Text {
                        text: modelData[1]
                        color: popup.theme.foreground
                        opacity: 0.78
                        font.pixelSize: 11
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                }
            }
            Item { Layout.fillHeight: true }
            Text { text: "Release Super to close"; color: popup.theme.foreground; opacity: 0.45; font.pixelSize: 9; Layout.fillWidth: true }
        }
    }
}
