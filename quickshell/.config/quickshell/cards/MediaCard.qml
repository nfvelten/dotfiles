import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

// Whatever is playing (or paused mid-track) over MPRIS.
Card {
    id: card
    required property QtObject media
    readonly property var player: {
        var all = Mpris.players.values
        return all.find(function(p) { return p.isPlaying }) || all.find(function(p) { return p.trackTitle && p.playbackState === MprisPlaybackState.Paused }) || null
    }
    active: feed.preferences.showMediaCard && (!!player || media.available)
    priority: media.playing ? 60 : 20
    title: "Spotify Player"
    key: "Space"
    function handleKey(text, key) {
        if (!player) return false
        if (key === Qt.Key_Space && player.canTogglePlaying) { player.togglePlaying(); return true }
        if (text === ">" && player.canGoNext) { player.next(); return true }
        if (text === "<" && player.canGoPrevious) { player.previous(); return true }
        return false
    }
    view: Component {
        CardFrame {
            theme: card.theme; title: card.title; hint: "Space " + (card.media.playing ? "pause" : "play") + " · < >"
            TapHandler { onTapped: card.feed.navigate("media") }
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Rectangle {
                    Layout.preferredWidth: 56; Layout.preferredHeight: 56
                    radius: 7; color: Qt.alpha(card.theme.foreground, 0.08); clip: true
                    Image {
                        id: artImage
                        anchors.fill: parent
                        visible: !!card.media.art || !!(card.player && card.player.trackArtUrl)
                        source: card.media.art || (card.player ? card.player.trackArtUrl : "")
                        sourceSize.width: 112; sourceSize.height: 112
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Text { anchors.centerIn: parent; visible: !artImage.visible; text: "♪"; color: card.theme.foreground; opacity: 0.35; font.pixelSize: 24 }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    RowLayout {
                        Layout.fillWidth: true; spacing: 7
                        Text { text: card.media.playing ? "Playing" : "Paused"; color: card.media.playing ? card.theme.accent : card.theme.foreground; opacity: card.media.playing ? 1 : 0.55; font.pixelSize: 10 }
                        Text { Layout.fillWidth: true; text: card.media.title || (card.player ? card.player.trackTitle : "Nothing playing"); color: card.theme.foreground; font.pixelSize: 14; textFormat: Text.PlainText; elide: Text.ElideRight }
                    }
                    Text { Layout.fillWidth: true; text: card.media.artist ? card.media.artist + (card.media.album ? " · " + card.media.album : "") : (card.player ? card.player.trackArtist : ""); color: card.theme.foreground; opacity: 0.6; font.pixelSize: 11; textFormat: Text.PlainText; elide: Text.ElideRight }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 7
                        Text { text: card.media.formatTime(card.media.currentPosition()); color: card.theme.foreground; opacity: 0.5; font.pixelSize: 10; font.family: "monospace" }
                        Rectangle {
                            Layout.fillWidth: true; height: 3; radius: 2
                            color: Qt.alpha(card.theme.foreground, 0.13)
                            Rectangle {
                                width: parent.width * (card.media.duration > 0 ? Math.min(1, card.media.currentPosition() / card.media.duration) : 0)
                                height: parent.height; radius: 2; color: card.theme.accent
                            }
                        }
                        Text { text: card.media.formatTime(card.media.duration); color: card.theme.foreground; opacity: 0.5; font.pixelSize: 10; font.family: "monospace" }
                    }
                }
                ColumnLayout {
                    Layout.preferredWidth: 28; spacing: 6
                    Text { text: "‹"; Layout.alignment: Qt.AlignHCenter; color: card.theme.foreground; opacity: card.player && card.player.canGoPrevious ? 0.8 : 0.25; font.pixelSize: 18
                        TapHandler { enabled: !!card.player && card.player.canGoPrevious; onTapped: card.player.previous() }
                    }
                    Text { text: card.media.playing ? "Ⅱ" : "▶"; Layout.alignment: Qt.AlignHCenter; color: card.theme.accent; font.pixelSize: 14
                        TapHandler { enabled: !!card.player && card.player.canTogglePlaying; onTapped: card.player.togglePlaying() }
                    }
                    Text { text: "›"; Layout.alignment: Qt.AlignHCenter; color: card.theme.foreground; opacity: card.player && card.player.canGoNext ? 0.8 : 0.25; font.pixelSize: 18
                        TapHandler { enabled: !!card.player && card.player.canGoNext; onTapped: card.player.next() }
                    }
                }
            }
        }
    }
}
