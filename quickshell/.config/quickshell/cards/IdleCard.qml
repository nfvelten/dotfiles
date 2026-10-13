import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Off work and nothing happening: suggest the book in zathura, a Radiola episode, fresh RSS.
Card {
    id: card
    property int workStart: 8
    property int workEnd: 18
    property var data: null
    property double now: Date.now()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: card.now = Date.now() }
    readonly property bool offWork: {
        var d = new Date(now), day = d.getDay(), hour = d.getHours()
        return day === 0 || day === 6 || hour < workStart || hour >= workEnd
    }
    readonly property string visibilityMode: feed.preferences ? feed.preferences.idleSuggestionsMode : "off-work"
    readonly property bool wanted: visibilityMode === "always" || (visibilityMode === "off-work" && offWork)
    readonly property var items: data && data.rss ? data.rss.items : []
    active: feed.preferences.showIdleCard && wanted && !!data && (!!data.book || !!data.podcast || items.length > 0)
    priority: 10
    title: "Off work · something worth your time"
    key: "l p 1–4"

    // Only read suggestions when they could be shown; RSS is fetched in the background.
    readonly property bool needed: wanted && feed.open
    onNeededChanged: { if (needed && !reader.running) reader.running = true }
    Process {
        id: reader
        command: ["python3", Quickshell.shellPath("idle_bridge.py"), "idle"]
        stdout: StdioCollector { onStreamFinished: { try { card.data = JSON.parse(text) } catch (e) {} } }
    }
    Process { id: fetcher; command: ["python3", Quickshell.shellPath("idle_bridge.py"), "refresh-rss"] }
    Timer { interval: 1800000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { if (!fetcher.running) fetcher.running = true } }

    function minutes(s) { return Math.round(s / 60) + " min" }
    function openBook() { Quickshell.execDetached(["uwsm", "app", "--", "zathura", data.book.file]); feed.closeRequested() }
    function playPodcast() {
        Quickshell.execDetached(["bash", "-c", "ui=\"$HOME/.local/share/radiola/ui/shell.qml\"; quickshell ipc -p \"$ui\" call radiola play \"$1\" 2>/dev/null || { radiola-ui & sleep 1.5; quickshell ipc -p \"$ui\" call radiola play \"$1\"; }", "radiola", String(data.podcast.id)])
        feed.closeRequested()
    }
    function openItem(item) { Quickshell.execDetached(["python3", Quickshell.shellPath("idle_bridge.py"), "open-rss", item.link]); feed.closeRequested() }
    function handleKey(text, key) {
        if (!active) return false
        if (text === "l" && data.book) { openBook(); return true }
        if (text === "p" && data.podcast) { playPodcast(); return true }
        var n = Number(text)
        if (n >= 1 && n <= items.length) { openItem(items[n - 1]); return true }
        return false
    }
    view: Component {
        CardFrame {
            theme: card.theme; title: card.title; hint: "l p 1–4"
            RowLayout {
                visible: !!card.data.book
                Layout.fillWidth: true; spacing: 10
                Text { text: "l"; color: card.theme.foreground; opacity: 0.45; font.family: "monospace"; font.pixelSize: 11 }
                Text { Layout.fillWidth: true; text: card.data.book ? "Keep reading " + card.data.book.title : ""; color: card.theme.foreground; font.pixelSize: 13; textFormat: Text.PlainText; elide: Text.ElideRight }
                Text { text: card.data.book ? "p. " + card.data.book.page : ""; color: card.theme.foreground; opacity: 0.6; font.pixelSize: 11 }
                TapHandler { onTapped: card.openBook() }
            }
            RowLayout {
                visible: !!card.data.podcast
                Layout.fillWidth: true; spacing: 10
                Text { text: "p"; color: card.theme.foreground; opacity: 0.45; font.family: "monospace"; font.pixelSize: 11 }
                Text { Layout.fillWidth: true; text: card.data.podcast ? (card.data.podcast.resume ? "Resume " : "New: ") + card.data.podcast.title + " · " + card.data.podcast.feed : ""; color: card.theme.foreground; font.pixelSize: 13; textFormat: Text.PlainText; elide: Text.ElideRight }
                Text { text: card.data.podcast && card.data.podcast.resume ? "at " + card.minutes(card.data.podcast.pos) : ""; color: card.theme.foreground; opacity: 0.6; font.pixelSize: 11 }
                TapHandler { onTapped: card.playPodcast() }
            }
            Rectangle { visible: card.items.length > 0; Layout.fillWidth: true; height: 1; color: Qt.alpha(card.theme.foreground, 0.1) }
            Repeater {
                model: card.items
                delegate: RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true; spacing: 10
                    Text { text: index + 1; color: card.theme.foreground; opacity: 0.45; font.family: "monospace"; font.pixelSize: 11 }
                    Column {
                        Layout.fillWidth: true; spacing: 2
                        Text { width: parent.width; text: modelData.title; color: card.theme.foreground; font.pixelSize: 12; textFormat: Text.PlainText; elide: Text.ElideRight }
                        Text { width: parent.width; text: modelData.source; color: card.theme.accent; opacity: 0.8; font.pixelSize: 10; textFormat: Text.PlainText; elide: Text.ElideRight }
                    }
                    TapHandler { onTapped: card.openItem(modelData) }
                }
            }
        }
    }
}
