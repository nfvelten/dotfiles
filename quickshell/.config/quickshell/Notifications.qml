import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: service
    required property QtObject theme
    // Locked screen or open dock: hide toasts and freeze their timers so nothing expires unseen.
    property bool paused: false
    readonly property bool dnd: memory.dnd
    readonly property var historyEntries: JSON.parse(memory.historyJson || "[]")
    // History survives shell restarts. Text snapshots only: actions stay live while the
    // original notification is still tracked by this session.
    Settings {
        id: memory
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/yerba-shell.ini"
        category: "notifications"
        property bool dnd: false
        property real dndUntil: 0  // 0 = until turned off
        property string historyJson: "[]"
        // Per-app rules: {"App name": "mute" | "always"}.
        property string appRulesJson: "{}"
        // Comma-separated, case-insensitive. A match in title or body pops up even when the app
        // is muted or Do Not Disturb is on (Teams arrives as "LibreWolf", so app rules can't tell mentions apart).
        property string alwaysKeywords: "@mentioned you"  // add your name via ipc setKeywords
        property real seenAt: 0
    }
    // Server ids restart at 1 with the shell, so history keys carry the session start.
    readonly property string session: String(Date.now())
    readonly property double seenAt: memory.seenAt
    function markSeen() { memory.seenAt = Date.now() }
    readonly property int unread: historyEntries.filter(function(e) { return e.time > memory.seenAt }).length
    function setHistory(entries) { memory.historyJson = JSON.stringify(entries) }
    function record(n) {
        if (n.transient) return
        var key = session + ":" + n.id
        var weekAgo = Date.now() - 7 * 86400000
        var entry = {key: key, id: n.id, app: n.appName, icon: n.appIcon, title: n.summary, body: n.body, critical: n.urgency === NotificationUrgency.Critical, time: Date.now()}
        setHistory([entry].concat(historyEntries.filter(function(e) { return e.key !== key && e.time > weekAgo })).slice(0, 50))
    }
    function removeEntry(key) { setHistory(historyEntries.filter(function(e) { return e.key !== key })) }
    function clearApp(app) { setHistory(historyEntries.filter(function(e) { return e.app !== app })) }
    function liveFor(key) {
        var values = server.trackedNotifications.values
        for (var i = 0; i < values.length; i++) if (session + ":" + values[i].id === key) return values[i]
        return null
    }
    function invokeAction(n, index) {
        if (n && n.actions[index]) n.actions[index].invoke()
    }
    function defaultIndex(n) {
        for (var i = 0; n && i < n.actions.length; i++) if (n.actions[i].identifier === "default") return i
        return -1
    }
    // Super + Shift + . opens this one: the newest popup that has something to open.
    readonly property var keyTarget: {
        var values = server.trackedNotifications.values
        for (var i = values.length - 1; i >= 0; i--) if (defaultIndex(values[i]) >= 0) return values[i]
        return null
    }
    // Returns false when the notification has no default action to run.
    function invokeDefault(n) {
        if (!n) return false
        for (var i = 0; i < n.actions.length; i++) {
            if (n.actions[i].identifier === "default") { invokeAction(n, i); return true }
        }
        return false
    }
    readonly property double dndUntil: memory.dndUntil
    function toggleDnd() { memory.dnd = !memory.dnd; memory.dndUntil = 0 }
    function snoozeDnd(minutes) { memory.dnd = true; memory.dndUntil = Date.now() + minutes * 60000 }
    function setDnd(on, until) { memory.dnd = on; memory.dndUntil = on ? until : 0 }
    Timer {
        interval: 15000; repeat: true; triggeredOnStart: true
        running: memory.dnd && memory.dndUntil > 0
        onTriggered: { if (Date.now() >= memory.dndUntil) { memory.dnd = false; memory.dndUntil = 0 } }
    }
    function clearHistory() { setHistory([]) }
    // mute: kept in history, no popup. always: pops up even during Do Not Disturb.
    // Critical notifications (e.g. low battery) always pop up.
    readonly property var appRules: JSON.parse(memory.appRulesJson || "{}")
    function ruleFor(app) { return appRules[app || "Notification"] || "" }
    function matchesKeyword(n) {
        var text = (n.summary + "\n" + n.body).toLowerCase()
        return memory.alwaysKeywords.split(",").some(function(k) { k = k.trim().toLowerCase(); return k && text.indexOf(k) >= 0 })
    }
    function setRule(app, rule) {
        var rules = JSON.parse(memory.appRulesJson || "{}")
        if (rule) rules[app || "Notification"] = rule
        else delete rules[app || "Notification"]
        memory.appRulesJson = JSON.stringify(rules)
    }
    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        onNotification: function(n) {
            n.tracked = true
            service.record(n)
            if (n.urgency === NotificationUrgency.Critical || service.matchesKeyword(n)) return
            var rule = service.ruleFor(n.appName)
            if (rule === "mute" || (memory.dnd && rule !== "always")) n.expire()
        }
    }
    IpcHandler {
        target: "notifications"
        function status(): string { return JSON.stringify({dnd: memory.dnd, active: server.trackedNotifications.values.length, history: service.historyEntries.length}) }
        function toggleDnd(): string { service.toggleDnd(); return memory.dnd ? "on" : "off" }
        function snoozeDnd(minutes: int): string { service.snoozeDnd(minutes); return "on for " + minutes + " min" }
        function clearHistory() { service.clearHistory() }
        function clearApp(app: string) { service.clearApp(app) }
        function setRule(app: string, rule: string): string { service.setRule(app, rule); return memory.appRulesJson }
        function rules(): string { return memory.appRulesJson }
        function setKeywords(keywords: string): string { memory.alwaysKeywords = keywords; return memory.alwaysKeywords }
        function keywords(): string { return memory.alwaysKeywords }
        function invokeLast() { service.invokeDefault(service.keyTarget) }
        function dismissOne() { var entries = server.trackedNotifications.values; if (entries.length) entries[entries.length - 1].dismiss() }
        function dismissAll() { server.trackedNotifications.values.slice().forEach(function(n) { n.dismiss() }) }
    }
    PanelWindow {
        id: popups
        visible: server.trackedNotifications.values.length > 0 && !service.paused
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
                    // Newest three; older ones wait (paused) until a slot frees up.
                    visible: index >= server.trackedNotifications.values.length - 3
                    width: stack.width
                    theme: service.theme
                    title: modelData.summary
                    body: modelData.body
                    app: modelData.appName
                    icon: modelData.image || modelData.appIcon
                    critical: modelData.urgency === NotificationUrgency.Critical
                    actions: modelData.actions
                    keyHint: modelData === service.keyTarget ? "Super ⇧ ." : ""
                    onDismissRequested: modelData.dismiss()
                    onActionRequested: function(i) { service.invokeAction(modelData, i) }
                    onDefaultRequested: service.invokeDefault(modelData)
                    property int remaining: modelData.expireTimeout > 0 ? modelData.expireTimeout : 8000
                    property double startedAt: 0
                    function restartLifetime() {
                        remaining = modelData.expireTimeout > 0 ? modelData.expireTimeout : 8000
                        lifetime.stop()
                        syncLifetime()
                    }
                    // The countdown only runs while the toast can actually be read.
                    function syncLifetime() {
                        var run = visible && !hovered && !critical && modelData.expireTimeout !== 0 && !service.paused
                        if (run && !lifetime.running) {
                            startedAt = Date.now()
                            lifetime.interval = Math.max(1, remaining)
                            lifetime.start()
                        } else if (!run && lifetime.running) {
                            remaining = Math.max(1, remaining - (Date.now() - startedAt))
                            lifetime.stop()
                        }
                    }
                    Component.onCompleted: syncLifetime()
                    onVisibleChanged: syncLifetime()
                    onHoveredChanged: syncLifetime()
                    Timer {
                        id: lifetime
                        repeat: false
                        onTriggered: toast.modelData.expire()
                    }
                    Connections {
                        target: service
                        function onPausedChanged() { toast.syncLifetime() }
                    }
                    Connections {
                        target: toast.modelData
                        function onSummaryChanged() { service.record(toast.modelData); toast.restartLifetime() }
                        function onExpireTimeoutChanged() { toast.restartLifetime() }
                        function onBodyChanged() { service.record(toast.modelData); toast.restartLifetime() }
                    }
                }
            }
        }
    }
}
