import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Item {
    id: surface
    required property var context

    Image {
        id: wallpaper
        anchors.fill: parent
        source: "file:///home/nfvelten/.local/state/desktop/background"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: status === Image.Ready
    }

    MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        blurEnabled: true
        blur: 0.65
        saturation: -0.25
        brightness: -0.2
    }

    Rectangle { anchors.fill: parent; color: Qt.alpha(context.theme.background, 0.72) }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(context.theme.background, 0.18) }
            GradientStop { position: 0.5; color: Qt.alpha(context.theme.background, 0.08) }
            GradientStop { position: 1.0; color: Qt.alpha(context.theme.background, 0.62) }
        }
    }

    Rectangle {
        width: Math.min(parent.width - 48, 430)
        height: card.height + 48
        anchors.centerIn: parent
        radius: 18
        color: Qt.alpha(context.theme.background, 0.94)
        border.color: Qt.alpha(context.theme.border, 0.62)
        border.width: 1

        Column {
            id: card
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 14

            Text {
                width: parent.width
                text: Qt.formatDateTime(new Date(), "ddd, dd MMM  •  HH:mm")
                color: context.theme.accent
                horizontalAlignment: Text.AlignHCenter
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 24
            }
            Text {
                width: parent.width
                text: "Session locked"
                color: context.theme.foreground
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 18
            }
            TextField {
                id: password
                width: parent.width
                height: 48
                enabled: !surface.context.authenticating
                echoMode: TextInput.Password
                placeholderText: "Password"
                color: context.theme.foreground
                placeholderTextColor: Qt.alpha(context.theme.foreground, 0.55)
                leftPadding: 16
                rightPadding: 16
                background: Rectangle {
                    color: Qt.alpha(context.theme.surface, 0.42)
                    border.color: password.activeFocus ? context.theme.accent : Qt.alpha(context.theme.border, 0.55)
                    border.width: password.activeFocus ? 2 : 1
                    radius: 10
                }
                onTextChanged: surface.context.password = text
                onAccepted: surface.context.authenticate()
                Component.onCompleted: forceActiveFocus()
            }
            Button {
                width: parent.width
                height: 42
                enabled: password.text.length > 0 && !surface.context.authenticating
                text: surface.context.authenticating ? "Checking…" : "Unlock"
                onClicked: surface.context.authenticate()
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? context.theme.background : Qt.alpha(context.theme.foreground, 0.45)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                }
                background: Rectangle {
                    color: parent.enabled ? context.theme.accent : Qt.alpha(context.theme.surface, 0.32)
                    radius: 10
                }
            }
            Text {
                width: parent.width
                visible: surface.context.statusText.length > 0
                text: surface.context.statusText
                color: context.theme.error
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 13
            }
            Text {
                width: parent.width
                text: "Press Enter to unlock"
                color: Qt.alpha(context.theme.foreground, 0.58)
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 12
            }
        }
    }
}
