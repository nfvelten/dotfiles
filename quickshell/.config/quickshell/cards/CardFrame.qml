import QtQuick
import QtQuick.Layouts

// Shared card chrome: title, key hint, optional accent for things that need you.
Rectangle {
    id: frame
    required property QtObject theme
    property string title: ""
    property string hint: ""
    property bool urgent: false
    // Set by the dashboard from preferences; collapsed shows only the header.
    property bool collapsed: false
    signal collapseToggled()
    default property alias content: body.data
    implicitHeight: column.implicitHeight + 24
    radius: 10
    color: urgent ? Qt.alpha(theme.accent, 0.09) : Qt.alpha(theme.foreground, 0.035)
    border.color: urgent ? Qt.alpha(theme.accent, 0.5) : Qt.alpha(theme.foreground, 0.12)
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }
    ColumnLayout {
        id: column
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 12
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: frame.title; color: frame.urgent ? theme.accent : theme.foreground; font.pixelSize: 13; elide: Text.ElideRight }
            Text { visible: !!frame.hint && !frame.collapsed; text: frame.hint; color: theme.foreground; opacity: 0.45; font.family: "monospace"; font.pixelSize: 11 }
            Text {
                text: frame.collapsed ? "▸" : "▾"
                color: theme.foreground; opacity: chevronMouse.containsMouse ? 0.9 : 0.4; font.pixelSize: 12
                // MouseArea (not TapHandler) so the click doesn't also reach the card's own TapHandler.
                MouseArea { id: chevronMouse; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: frame.collapseToggled() }
            }
        }
        ColumnLayout { id: body; visible: !frame.collapsed; Layout.fillWidth: true; spacing: 6 }
    }
}
