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
    // Shown on the default ("Open") button when a global shortcut runs it.
    property string keyHint: ""
    readonly property bool hovered: hover.hovered
    signal dismissRequested()
    signal actionRequested(int actionIndex)
    signal defaultRequested()
    // Album art and screenshots are files/URLs; theme icon names stay small.
    // image-path hints arrive as image://icon/<value>; a file path there is art, a name is a theme icon.
    readonly property string iconPath: icon.startsWith("image://icon//") ? icon.slice(13) : icon
    // Track-change popups from music players get live spectrum bars under the text.
    readonly property bool isMusic: isArt && /spotify|music|player|mpd|radiola/i.test(app)
    readonly property bool isArt: iconPath.startsWith("/") || (iconPath.indexOf("://") >= 0 && !iconPath.startsWith("image://icon/"))
    implicitHeight: content.implicitHeight + 24
    color: theme.background
    radius: 7
    border.width: 1
    border.color: card.critical ? theme.error : theme.border
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }
    HoverHandler { id: hover }
    TapHandler { onTapped: card.defaultRequested() }
    RowLayout {
        id: content
        x: 12; y: 12; width: parent.width - 24
        spacing: 12
        Rectangle {
            visible: card.icon !== "" && image.status !== Image.Error
            Layout.alignment: Qt.AlignTop
            readonly property real size: card.isArt ? Math.max(56, Math.min(84, textColumn.implicitHeight)) : 32
            Layout.preferredWidth: size; Layout.preferredHeight: size
            radius: 5; clip: true; color: "transparent"
            Image {
                id: image
                anchors.fill: parent
                source: !card.iconPath ? "" : card.iconPath.startsWith("/") ? "file://" + card.iconPath : card.iconPath.indexOf(":") >= 0 ? card.iconPath : Quickshell.iconPath(card.iconPath)
                sourceSize.width: 168; sourceSize.height: 168
                fillMode: card.isArt ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                asynchronous: true
            }
        }
        ColumnLayout {
            id: textColumn
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 3
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: card.app || "Notification"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: theme.foreground; opacity: 0.55; font.pixelSize: 11
                }
                Rectangle {
                    width: 20; height: 20; radius: 3
                    color: closeMouse.containsMouse ? theme.surface : "transparent"
                    Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 16; color: theme.foreground }
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
            Visualizer {
                visible: card.isMusic
                Layout.fillWidth: true; Layout.topMargin: 4
                implicitHeight: 18
                theme: card.theme
            }
            Flow {
                Layout.fillWidth: true; Layout.topMargin: 4
                visible: card.actions.length > 0
                spacing: 6
                Repeater {
                    model: card.actions
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property string hint: modelData.identifier === "default" ? card.keyHint : ""
                        width: Math.min(actionRow.implicitWidth + 18, textColumn.width)
                        height: 28; radius: 4; color: theme.surface
                        Row {
                            id: actionRow
                            anchors.centerIn: parent
                            spacing: 8
                            Text { width: Math.min(implicitWidth, textColumn.width - 18); text: modelData.text; textFormat: Text.PlainText; elide: Text.ElideRight; color: theme.foreground; font.pixelSize: 12 }
                            Text { visible: text !== ""; text: parent.parent.hint; textFormat: Text.PlainText; color: theme.foreground; opacity: 0.55; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { anchors.fill: parent; onClicked: card.actionRequested(index) }
                    }
                }
            }
        }
    }
}
