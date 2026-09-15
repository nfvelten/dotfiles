import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    Theme { id: palette }
    Settings {
        id: preferences
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/yerba-shell.ini"
        category: "desktop"
        property bool showTopBar: false
    }
    function toggleTopBar() {
        preferences.showTopBar = !preferences.showTopBar
        preferences.sync()
    }
    property bool menuOpen: false
    property string now: Qt.formatDateTime(new Date(), "ddd HH:mm")

    IpcHandler {
        target: "yerba"
        function status(): string { return JSON.stringify({requested: root.menuOpen, open: menu.isOpen, visible: menu.visible, topBar: preferences.showTopBar, dockStatus: menu.isOpen && !preferences.showTopBar}) }
        function toggleTopBar() { root.toggleTopBar() }
        function toggleMenu() { root.menuOpen = !root.menuOpen }
        function powerMenu() { menu.route = "power"; root.menuOpen = true }
        function closeMenu() { root.menuOpen = false }
    }

    Notifications { id: notifications; theme: palette }
    Bar { visible: preferences.showTopBar; theme: palette; time: root.now; onMenuRequested: root.menuOpen = !root.menuOpen }
    Menu { id: menu; showTopBar: preferences.showTopBar; time: root.now; onToggleTopBarRequested: root.toggleTopBar(); notifications: notifications; theme: palette; isOpen: root.menuOpen; onCloseRequested: root.menuOpen = false }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: now = Qt.formatDateTime(new Date(), "ddd HH:mm")
    }
}
