import QtQuick
import QtQuick.Layouts

// Notifications from the last two hours you haven't cleared from the dashboard.
Card {
    id: card
    property double now: Date.now()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: card.now = Date.now() }
    readonly property var recent: feed.notifications.historyEntries.filter(function(e) {
        return e.time && e.time > feed.notifications.seenAt && card.now - e.time < 7200000
    })
    readonly property bool critical: recent.some(function(e) { return e.critical })
    active: feed.preferences.showNotificationsCard && recent.length > 0
    priority: critical ? 90 : 80
    title: recent.length + (recent.length > 1 ? " notifications" : " notification")
    key: "x"
    function ago(t) { var m = Math.round((now - t) / 60000); return m < 1 ? "now" : m < 60 ? m + " min" : Math.round(m / 60) + " h" }
    function handleKey(text, key) {
        if (text === "x" && recent.length) { feed.notifications.markSeen(); return true }
        return false
    }
    view: Component {
        CardFrame {
            theme: card.theme; title: card.title; hint: "x clear"; urgent: card.critical
            TapHandler { onTapped: card.feed.navigate("notifications") }
            Repeater {
                model: card.recent.slice(0, 3)
                delegate: Column {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 2
                    Row {
                        width: parent.width; spacing: 8
                        Text { text: modelData.app || "App"; color: card.theme.accent; font.pixelSize: 11 }
                        Text { text: card.ago(modelData.time); color: card.theme.foreground; opacity: 0.45; font.pixelSize: 11 }
                    }
                    Text { width: parent.width; text: modelData.title; color: card.theme.foreground; font.pixelSize: 13; textFormat: Text.PlainText; elide: Text.ElideRight }
                    Text { visible: !!modelData.body; width: parent.width; text: modelData.body; color: card.theme.foreground; opacity: 0.6; font.pixelSize: 11; textFormat: Text.PlainText; elide: Text.ElideRight }
                }
            }
        }
    }
}
