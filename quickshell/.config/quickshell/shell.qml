import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    Theme { id: palette }
    property bool menuOpen: false
    property string now: Qt.formatDateTime(new Date(), "ddd HH:mm")

    IpcHandler {
        target: "yerba"
        function status(): string { return JSON.stringify({requested: root.menuOpen, open: menu.isOpen, visible: menu.visible}) }
        function toggleMenu() { root.menuOpen = !root.menuOpen }
        function powerMenu() { menu.route = "power"; root.menuOpen = true }
        function closeMenu() { root.menuOpen = false }
    }

    Notifications { id: notifications; theme: palette }
    Bar { theme: palette; time: root.now; onMenuRequested: root.menuOpen = !root.menuOpen }
    Menu { id: menu; notifications: notifications; theme: palette; isOpen: root.menuOpen; onCloseRequested: root.menuOpen = false }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: now = Qt.formatDateTime(new Date(), "ddd HH:mm")
    }
}
