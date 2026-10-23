import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit

// Polkit agent (pkexec, systemctl, …) drawn in the shell theme; replaces hyprpolkitagent.
Scope {
    id: root
    required property QtObject theme
    readonly property var flow: agent.flow

    PolkitAgent { id: agent }

    PanelWindow {
        visible: agent.isActive && !!root.flow
        anchors { top: true; left: true; right: true; bottom: true }
        exclusiveZone: -1
        color: Qt.alpha(root.theme.background, 0.55)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "yerba-polkit"

        Rectangle {
            width: Math.min(parent.width - 48, 430)
            height: card.height + 48
            anchors.centerIn: parent
            radius: 18
            color: Qt.alpha(root.theme.background, 0.96)
            border.color: Qt.alpha(root.theme.border, 0.62)

            Column {
                id: card
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 14
                Text {
                    width: parent.width
                    text: "Authentication required"
                    color: root.theme.accent
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 18
                }
                Text {
                    width: parent.width
                    text: root.flow ? root.flow.message : ""
                    color: root.theme.foreground
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    font.pixelSize: 13
                }
                TextField {
                    id: password
                    width: parent.width
                    height: 48
                    enabled: !!root.flow && root.flow.isResponseRequired
                    echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                    placeholderText: root.flow && root.flow.inputPrompt ? root.flow.inputPrompt.replace(/:\s*$/, "") : "Password"
                    color: root.theme.foreground
                    placeholderTextColor: Qt.alpha(root.theme.foreground, 0.55)
                    leftPadding: 16
                    rightPadding: 16
                    background: Rectangle {
                        color: Qt.alpha(root.theme.surface, 0.42)
                        border.color: password.activeFocus ? root.theme.accent : Qt.alpha(root.theme.border, 0.55)
                        border.width: password.activeFocus ? 2 : 1
                        radius: 10
                    }
                    onAccepted: if (root.flow && text.length) { root.flow.submit(text); text = "" }
                    Keys.onEscapePressed: if (root.flow) root.flow.cancelAuthenticationRequest()
                    onEnabledChanged: if (enabled) forceActiveFocus()
                    onVisibleChanged: if (visible) forceActiveFocus()
                }
                Text {
                    width: parent.width
                    visible: !!root.flow && !!root.flow.supplementaryMessage
                    text: root.flow ? root.flow.supplementaryMessage : ""
                    color: root.flow && root.flow.supplementaryIsError ? root.theme.error : Qt.alpha(root.theme.foreground, 0.7)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    font.pixelSize: 13
                }
                Text {
                    width: parent.width
                    text: "Enter authenticate · Esc cancel"
                    color: Qt.alpha(root.theme.foreground, 0.58)
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 12
                }
            }
        }
    }
}
