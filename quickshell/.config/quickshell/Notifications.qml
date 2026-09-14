import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: service
    required property QtObject theme
    property bool historyOpen: false
    readonly property bool dnd: memory.dnd
    // Bounded session history; text snapshots never retain dead notification objects.
    PersistentProperties {
        id: memory
        reloadableId: "yerba-notifications"
        property bool dnd: false
        property var history: []
    }
    function record(n) {
        if (n.transient) return
        var entry = {id: n.id, app: n.appName, title: n.summary, body: n.body, critical: n.urgency === NotificationUrgency.Critical}
        memory.history = [entry].concat(memory.history.filter(function(e) { return e.id !== n.id })).slice(0, 10)
    }
    function toggleDnd() { memory.dnd = !memory.dnd }
    function clearHistory() { memory.history = [] }
    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: false
        onNotification: function(n) {
            n.tracked = true
            service.record(n)
            if (memory.dnd && n.urgency !== NotificationUrgency.Critical) n.expire()
        }
    }
    IpcHandler {
        target: "notifications"
        function status(): string { return JSON.stringify({dnd: memory.dnd, active: server.trackedNotifications.values.length, history: memory.history.length, historyOpen: service.historyOpen}) }
        function toggleDnd(): string { service.toggleDnd(); return memory.dnd ? "on" : "off" }
        function showHistory() { service.historyOpen = true }
        function closeHistory() { service.historyOpen = false }
        function clearHistory() { service.clearHistory() }
        function dismissAll() { server.trackedNotifications.values.slice().forEach(function(n) { n.dismiss() }) }
    }
    PanelWindow {
        id: popups
        visible: server.trackedNotifications.values.length > 0
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "yerba-notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { item: stack }
        Column {
            id: stack
            anchors.top: parent.top; anchors.topMargin: 52
            anchors.right: parent.right; anchors.rightMargin: 12
            width: Math.min(380, parent.width - 24)
            spacing: 8
            Repeater {
                model: server.trackedNotifications
                delegate: NotificationCard {
                    id: toast
                    required property var modelData
                    required property int index
                    visible: index < 3
                    width: stack.width
                    theme: service.theme
                    title: modelData.summary
                    body: modelData.body
                    app: modelData.appName
                    icon: modelData.appIcon
                    critical: modelData.urgency === NotificationUrgency.Critical
                    actions: modelData.actions
                    onDismissRequested: modelData.dismiss()
                    onActionRequested: function(i) { if (modelData.actions[i]) modelData.actions[i].invoke() }
                    onDefaultRequested: {
                        for (var i = 0; i < modelData.actions.length; i++) {
                            if (modelData.actions[i].identifier === "default") { modelData.actions[i].invoke(); return }
                        }
                    }
                    property int remaining: modelData.expireTimeout > 0 ? modelData.expireTimeout : 8000
                    property double startedAt: 0
                    function restartLifetime() {
                        remaining = modelData.expireTimeout > 0 ? modelData.expireTimeout : 8000
                        lifetime.stop()
                        resumeLifetime()
                    }
                    function resumeLifetime() {
                        if (!visible || hovered || critical || modelData.expireTimeout === 0) return
                        startedAt = Date.now()
                        lifetime.interval = Math.max(1, remaining)
                        lifetime.start()
                    }
                    Component.onCompleted: resumeLifetime()
                    onVisibleChanged: { if (visible) resumeLifetime() }
                    onHoveredChanged: {
                        if (hovered && lifetime.running) {
                            remaining = Math.max(1, remaining - (Date.now() - startedAt))
                            lifetime.stop()
                        } else if (!hovered) resumeLifetime()
                    }
                    Timer {
                        id: lifetime
                        repeat: false
                        onTriggered: toast.modelData.expire()
                    }
                    Connections {
                        target: toast.modelData
                        function onSummaryChanged() { service.record(toast.modelData); toast.restartLifetime() }
                        function onBodyChanged() { service.record(toast.modelData); toast.restartLifetime() }
                    }
                }
            }
        }
    }
    PanelWindow {
        id: historyWindow
        visible: service.historyOpen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "yerba-notification-history"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: service.historyOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        MouseArea { anchors.fill: parent; onClicked: service.historyOpen = false }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(600, parent.width - 32)
            height: Math.min(500, parent.height - 64)
            radius: 7; color: service.theme.background; border.color: service.theme.border
            MouseArea { anchors.fill: parent }
            focus: true
            Keys.onEscapePressed: service.historyOpen = false
            Text { x: 16; y: 16; text: "Notifications · Session history"; color: service.theme.foreground; font.pixelSize: 15 }
            Text { anchors.right: parent.right; anchors.rightMargin: 16; y: 18; text: "Esc close"; color: service.theme.foreground; opacity: 0.6; font.pixelSize: 11 }
            ListView {
                anchors.fill: parent; anchors.margins: 12; anchors.topMargin: 50
                spacing: 8; clip: true; focus: true
                model: memory.history
                delegate: NotificationCard {
                    required property var modelData
                    width: ListView.view.width
                    theme: service.theme
                    title: modelData.title; body: modelData.body; app: modelData.app; critical: modelData.critical
                    onDismissRequested: memory.history = memory.history.filter(function(e) { return e.id !== modelData.id })
                }
                Text { anchors.centerIn: parent; visible: memory.history.length === 0; text: "No notifications yet"; color: service.theme.foreground; opacity: 0.65 }
            }
        }
    }
}
