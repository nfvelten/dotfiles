import QtQuick
import QtQuick.Layouts

Card {
    id: card
    required property QtObject podcast
    active: feed.preferences.showPodcastCard !== false && podcast.available
    priority: podcast.playing ? 55 : 25
    title: "Podcast Player"
    key: "Space"

    function handleKey(text, key) {
        if (!active) return false
        if (key === Qt.Key_Space) { podcast.toggle(); return true }
        if (text === "o") { podcast.open(); return true }
        return false
    }
    view: Component {
        CardFrame {
            theme: card.theme; title: card.title; hint: "Space " + (podcast.playing ? "pause" : "play") + " · o open"
            TapHandler { onTapped: podcast.open() }
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Rectangle {
                    Layout.preferredWidth: 56; Layout.preferredHeight: 56
                    radius: 7; color: Qt.alpha(card.theme.foreground, 0.08)
                    Text { anchors.centerIn: parent; text: "◉"; color: card.theme.accent; font.pixelSize: 26 }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    RowLayout {
                        Layout.fillWidth: true; spacing: 7
                        Text { text: podcast.playing ? "Playing" : "Paused"; color: podcast.playing ? card.theme.accent : card.theme.foreground; opacity: podcast.playing ? 1 : 0.55; font.pixelSize: 10 }
                        Text { Layout.fillWidth: true; text: podcast.title; color: card.theme.foreground; font.pixelSize: 14; textFormat: Text.PlainText; elide: Text.ElideRight }
                    }
                    Text { Layout.fillWidth: true; text: podcast.feed; color: card.theme.foreground; opacity: 0.6; font.pixelSize: 11; textFormat: Text.PlainText; elide: Text.ElideRight }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 7
                        Text { text: podcast.formatTime(podcast.currentPosition()); color: card.theme.foreground; opacity: 0.5; font.pixelSize: 10; font.family: "monospace" }
                        Rectangle {
                            Layout.fillWidth: true; height: 3; radius: 2; color: Qt.alpha(card.theme.foreground, 0.13)
                            Rectangle { width: parent.width * (podcast.duration > 0 ? Math.min(1, podcast.currentPosition() / podcast.duration) : 0); height: parent.height; radius: 2; color: card.theme.accent }
                        }
                        Text { text: podcast.formatTime(podcast.duration); color: card.theme.foreground; opacity: 0.5; font.pixelSize: 10; font.family: "monospace" }
                    }
                }
                ColumnLayout {
                    Layout.preferredWidth: 28; spacing: 6
                    Text { text: podcast.playing ? "Ⅱ" : "▶"; Layout.alignment: Qt.AlignHCenter; color: card.theme.accent; font.pixelSize: 14; TapHandler { onTapped: podcast.toggle() } }
                    Text { text: "■"; Layout.alignment: Qt.AlignHCenter; color: card.theme.foreground; opacity: 0.55; font.pixelSize: 11; TapHandler { onTapped: podcast.stop() } }
                }
            }
        }
    }
}
