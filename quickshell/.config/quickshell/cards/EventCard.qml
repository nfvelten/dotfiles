import QtQuick
import QtQuick.Layouts

// Shows up only when something on the agenda starts within the hour (or is happening now).
Card {
    id: card
    property double now: Date.now()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: card.now = Date.now() }
    function startOf(e) {
        if (!e.time) return NaN
        var p = e.date.split("-"), t = e.time.split(":")
        return new Date(p[0], p[1] - 1, p[2], t[0], t[1]).getTime()
    }
    readonly property var soon: feed.org.events.filter(function(e) {
        var start = startOf(e)
        return start - card.now < 3600000 && start - card.now > -1800000
    }).sort(function(a, b) { return startOf(a) - startOf(b) })
    active: feed.preferences.showEventsCard && soon.length > 0
    priority: 70
    title: "Coming up"
    key: "C"
    view: Component {
        CardFrame {
            theme: card.theme; title: card.title; hint: "C calendar"
            TapHandler { onTapped: card.feed.navigate("calendar") }
            Repeater {
                model: card.soon.slice(0, 2)
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 10
                    Text {
                        readonly property int minutes: Math.round((card.startOf(modelData) - card.now) / 60000)
                        text: minutes > 0 ? "in " + minutes + " min" : "now"
                        color: card.theme.accent; font.pixelSize: 12
                    }
                    Text { Layout.fillWidth: true; text: modelData.time + "  " + modelData.title; color: card.theme.foreground; font.pixelSize: 13; textFormat: Text.PlainText; elide: Text.ElideRight }
                }
            }
        }
    }
}
