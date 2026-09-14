import QtQuick
import Quickshell
import Quickshell.Wayland
import "Actions.js" as Actions

PanelWindow {
    id: panel
    signal closeRequested()
    required property QtObject theme
    required property QtObject notifications
    property bool isOpen: false
    property string query: ""
    property string route: "main"
    property var pending: null
    property int selected: 0
    readonly property var rows: filtered()
    onIsOpenChanged: {
        if (isOpen) { query = ""; selected = 0; search.forceActiveFocus() }
        else { route = "main"; pending = null }
    }
    function activate(index) {
        var item = rows[index]
        if (!item) return
        if (item.notificationAction) {
            if (item.notificationAction === "dnd") notifications.toggleDnd()
            if (item.notificationAction === "clear") notifications.clearHistory()
            if (item.notificationAction === "history") { panel.closeRequested(); notifications.historyOpen = true }
            return
        }
        if (item.cancel) { pending = null; return }
        if (item.route) { route = item.route; query = ""; selected = 0; return }
        if (item.confirm) { pending = item; query = ""; selected = 0; return }
        Quickshell.execDetached(["bash", "-lc", item.command])
        panel.closeRequested()
    }

    function filtered() {
        var q = query.toLowerCase().trim()
        if (pending) return [{title: "Cancel", cancel: true}, {title: "Confirm " + pending.title, command: pending.command}]
        var source = route === "power" ? Actions.power() : Actions.all()
        var notificationActions = [
            {title: "Do not disturb: " + (notifications.dnd ? "On" : "Off"), keywords: "Toggle notification popups", notificationAction: "dnd"},
            {title: "Notification history", keywords: "Recent notifications from this session", notificationAction: "history"},
            {title: "Clear notification history", keywords: "Forget recent notifications", notificationAction: "clear"}
        ]
        if (route === "notifications") source = notificationActions
        else if (q && route === "main") source = source.concat(notificationActions)
        if (!q) return source
        return source.filter(function (item) { return (item.title + " " + item.keywords).toLowerCase().indexOf(q) >= 0 })
    }

    visible: panel.isOpen
    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "yerba-menu"
    WlrLayershell.keyboardFocus: panel.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None


    MouseArea {
        anchors.fill: parent
        onClicked: panel.closeRequested()
    }

    Rectangle {
        id: dock
        width: Math.min(740, parent.width - 32)
        height: Math.min(parent.height - 48, 132 + Math.min(5, Math.max(1, panel.rows.length)) * 48)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        radius: 7
        color: theme.background
        border.color: theme.border
        border.width: 1
        clip: true

        MouseArea { anchors.fill: parent }
        Rectangle {
            width: parent.width - 2
            height: 2
            x: 1
            color: theme.accent
        }
        Item {
            id: header
            height: 54
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            Text {
                id: prefix
                text: panel.route === "power" ? "Power" : "Open"
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                color: theme.foreground
                font.pixelSize: 14
            }
            TextInput {
                id: search
                anchors.left: prefix.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 74
                anchors.verticalCenter: parent.verticalCenter
                color: theme.foreground
                font.pixelSize: 15
                clip: true
                text: panel.query
                onTextChanged: { panel.query = text; panel.selected = 0 }
                Text {
                    visible: !search.text
                    text: "Search apps and actions"
                    color: theme.foreground
                    opacity: 0.6
                    font.pixelSize: 15
                }
                Keys.onEscapePressed: panel.closeRequested()
                Keys.onDownPressed: panel.selected = Math.min(panel.rows.length - 1, panel.selected + 1)
                Keys.onUpPressed: panel.selected = Math.max(0, panel.selected - 1)
                Keys.onTabPressed: panel.selected = panel.rows.length ? (panel.selected + 1) % panel.rows.length : 0
                Keys.onReturnPressed: panel.activate(panel.selected)
                Keys.onEnterPressed: panel.activate(panel.selected)
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: "Esc"
                color: theme.foreground
                opacity: 0.6
                font.family: "monospace"
                font.pixelSize: 11
            }
        }
        Rectangle {
            anchors.top: header.bottom
            width: parent.width
            height: 1
            color: theme.border
            opacity: 0.5
        }
        Item {
            id: section
            anchors.top: header.bottom
            width: parent.width
            height: 30
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: panel.pending ? "Confirmation" : "Commands"
                color: theme.foreground
                opacity: 0.6
                font.pixelSize: 12
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: panel.rows.length + " actions"
                color: theme.foreground
                opacity: 0.6
                font.pixelSize: 12
            }
        }
        ListView {
            id: results
            anchors.top: section.bottom
            anchors.bottom: footer.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            clip: true
            model: panel.rows
            currentIndex: panel.selected
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: Rectangle {
                required property int index
                required property var modelData
                width: results.width
                height: 48
                radius: 4
                color: index === panel.selected ? theme.surface : "transparent"
                Text {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(index + 1).padStart(2, "0")
                    color: theme.foreground
                    opacity: 0.55
                    font.family: "monospace"
                    font.pixelSize: 11
                }
                Column {
                    x: 36
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text { text: modelData.title; color: theme.foreground; font.pixelSize: 14 }
                    Text {
                        text: modelData.keywords || (modelData.cancel ? "Return without changes" : "Session action")
                        color: theme.foreground
                        opacity: 0.6
                        font.family: "monospace"
                        font.pixelSize: 11
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: panel.selected = index
                    onClicked: panel.activate(index)
                }
            }
            Text {
                anchors.centerIn: parent
                visible: panel.rows.length === 0
                text: "No matching actions"
                color: theme.foreground
                opacity: 0.6
            }
        }
        Item {
            id: footer
            anchors.bottom: parent.bottom
            width: parent.width
            height: 32
            Rectangle { width: parent.width; height: 1; color: theme.border; opacity: 0.5 }
            Text {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "↑ ↓ / Tab navigate    Enter open    Esc close"
                font.pixelSize: 11
                color: theme.foreground
                opacity: 0.7
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "Desktop"
                font.pixelSize: 11
                color: theme.foreground
                opacity: 0.6
            }
        }
    }
}
