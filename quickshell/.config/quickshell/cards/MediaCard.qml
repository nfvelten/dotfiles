import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

// Whatever is playing, or paused mid-track. Spotify uses the richer bridge data;
// any other MPRIS player (e.g. a browser video) shows its own metadata.
Card {
    id: card
    required property QtObject media
    readonly property var player: {
        var all = Mpris.players.values.filter(function(p) { return p.dbusName !== "org.mpris.MediaPlayer2.playerctld" })
        function spotify(p) { return p.dbusName === "org.mpris.MediaPlayer2.spotify_player" }
        // A track merely loaded at 0:00 doesn't count as paused playback.
        function paused(p) { return p.trackTitle && p.playbackState === MprisPlaybackState.Paused && p.position > 0 }
        return all.find(function(p) { return p.isPlaying && spotify(p) }) || all.find(function(p) { return p.isPlaying })
            || all.find(function(p) { return paused(p) && spotify(p) }) || all.find(paused) || null
    }
    readonly property bool isSpotify: !!player && player.dbusName === "org.mpris.MediaPlayer2.spotify_player"
    readonly property bool playing: isSpotify ? media.playing : !!player && player.isPlaying
    readonly property string trackTitle: isSpotify && media.title ? media.title : player ? player.trackTitle : ""
    readonly property string trackInfo: isSpotify && media.artist ? media.artist + (media.album ? " · " + media.album : "") : player ? [player.trackArtist, player.trackAlbum].filter(function(x) { return x }).join(" · ") : ""
    readonly property string artUrl: isSpotify && media.art ? media.art : player ? player.trackArtUrl : ""
    // Milliseconds, like the Spotify bridge; MPRIS reports seconds and needs polling for position.
    readonly property real duration: isSpotify ? media.duration : player && player.lengthSupported ? player.length * 1000 : 0
    property int tick: 0
    Timer { interval: 1000; repeat: true; running: !!card.player && !card.isSpotify && card.playing; onTriggered: { card.player.positionChanged(); card.tick++ } }
    function position() { tick; return isSpotify ? media.currentPosition() : player ? player.position * 1000 : 0 }
    active: feed.preferences.showMediaCard && (!!player || media.playing)
    priority: playing ? 60 : 20
    title: isSpotify || !player ? "Spotify Player" : (player.identity || "Now playing")
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
            theme: card.theme; title: card.title; hint: "Space " + (card.playing ? "pause" : "play") + " · < >"
            TapHandler { onTapped: card.feed.navigate("media") }
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Rectangle {
                    Layout.preferredWidth: 56; Layout.preferredHeight: 56
                    radius: 7; color: Qt.alpha(card.theme.foreground, 0.08); clip: true
                    Image {
                        id: artImage
                        anchors.fill: parent
                        visible: !!card.artUrl
                        source: card.artUrl
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
                        Text { text: card.playing ? "Playing" : "Paused"; color: card.playing ? card.theme.accent : card.theme.foreground; opacity: card.playing ? 1 : 0.55; font.pixelSize: 10 }
                        Text { Layout.fillWidth: true; text: card.trackTitle || "Nothing playing"; color: card.theme.foreground; font.pixelSize: 14; textFormat: Text.PlainText; elide: Text.ElideRight }
                    }
                    Text { Layout.fillWidth: true; text: card.trackInfo; color: card.theme.foreground; opacity: 0.6; font.pixelSize: 11; textFormat: Text.PlainText; elide: Text.ElideRight }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 7
                        Text { text: card.media.formatTime(card.position()); color: card.theme.foreground; opacity: 0.5; font.pixelSize: 10; font.family: "monospace" }
                        Rectangle {
                            Layout.fillWidth: true; height: 3; radius: 2
                            color: Qt.alpha(card.theme.foreground, 0.13)
                            Rectangle {
                                width: parent.width * (card.duration > 0 ? Math.min(1, card.position() / card.duration) : 0)
                                height: parent.height; radius: 2; color: card.theme.accent
                            }
                        }
                        Text { text: card.duration > 0 ? card.media.formatTime(card.duration) : "live"; color: card.theme.foreground; opacity: 0.5; font.pixelSize: 10; font.family: "monospace" }
                    }
                }
                ColumnLayout {
                    Layout.preferredWidth: 28; spacing: 6
                    Text { text: "‹"; Layout.alignment: Qt.AlignHCenter; color: card.theme.foreground; opacity: card.player && card.player.canGoPrevious ? 0.8 : 0.25; font.pixelSize: 18
                        TapHandler { enabled: !!card.player && card.player.canGoPrevious; onTapped: card.player.previous() }
                    }
                    Text { text: card.playing ? "Ⅱ" : "▶"; Layout.alignment: Qt.AlignHCenter; color: card.theme.accent; font.pixelSize: 14
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
