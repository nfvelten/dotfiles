import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: card
    required property QtObject theme
    property string title: ""
    property string body: ""
    property string app: ""
    property string icon: ""
    property bool critical: false
    property var actions: []
    readonly property bool hovered: hover.hovered
    signal dismissRequested()
    signal actionRequested(int actionIndex)
    signal defaultRequested()
    implicitHeight: content.implicitHeight + 28
    color: theme.background
    radius: 7
    border.width: 1
    border.color: theme.border
    HoverHandler { id: hover }
    TapHandler { onTapped: card.defaultRequested() }
    Rectangle { x: 7; width: parent.width - 14; height: 2; color: card.critical ? "#c25d44" : theme.accent }
    ColumnLayout {
        id: content
        x: 14; y: 14; width: parent.width - 28
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Image {
                visible: card.icon !== "" && status !== Image.Error
                source: card.icon.startsWith("/") ? "file://" + card.icon : card.icon.indexOf(":") >= 0 ? card.icon : Quickshell.iconPath(card.icon)
                sourceSize.width: 28; sourceSize.height: 28
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                fillMode: Image.PreserveAspectFit
            }
            Text {
                Layout.fillWidth: true
                text: card.app || "Notification"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: theme.foreground; opacity: 0.65; font.pixelSize: 11
            }
            Rectangle {
                width: 22; height: 22; radius: 3
                color: closeMouse.containsMouse ? theme.surface : "transparent"
                Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 18; color: theme.foreground }
                MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: card.dismissRequested() }
            }
        }
        Text {
            Layout.fillWidth: true
            text: card.title; textFormat: Text.PlainText
            wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
            color: theme.foreground; font.pixelSize: 14; font.bold: true
        }
        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: card.body; textFormat: Text.PlainText
            wrapMode: Text.Wrap; maximumLineCount: 6; elide: Text.ElideRight
            color: theme.foreground; opacity: 0.75; font.pixelSize: 13
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: card.actions
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: Math.min(actionText.implicitWidth + 18, content.width)
                    height: 28; radius: 4; color: theme.surface
                    Text { id: actionText; anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - 18); text: modelData.text; textFormat: Text.PlainText; elide: Text.ElideRight; color: theme.foreground; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; onClicked: card.actionRequested(index) }
                }
            }
        }
    }
}
