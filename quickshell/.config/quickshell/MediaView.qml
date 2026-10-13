import QtQuick
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io

FocusScope {
    id: view
    required property QtObject theme
    required property QtObject media
    required property QtObject buttonPreferences
    property QtObject player: null
    signal back()
    signal closeRequested()
    signal helpRequested()
    function focusSearch() { searchInput.forceActiveFocus() }
    property string query: ""
    property var results: []
    property var playlists: []
    property var tracks: []
    property var queueItems: []
    property var recentItems: []
    property string mode: "library"
    property string playlistTitle: ""
    property string playlistId: ""
    property int selected: 0
    property string error: ""
    property bool searching: searchProcess.running
    property bool playing: playProcess.running
    property bool loading: libraryProcess.running || playlistProcess.running || queueProcess.running || recentProcess.running
    readonly property bool showButtons: buttonPreferences.showButtons
    Settings {
        id: saved
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/yerba-shell.ini"
        category: "media"
        property string playlistsJson: "[]"
        property double playlistsCachedAt: 0
        property int playlistsCacheVersion: 2
    }
    Connections {
        target: media
        function onAvailableChanged() { if (media.available) view.error = "" }
    }
    function toggleButtons() { buttonPreferences.showButtons = !buttonPreferences.showButtons; buttonPreferences.sync() }
    readonly property bool searchVisible: mode === "search" || query.trim().length > 0
    function closeSearch() {
        query = ""
        if (mode === "search") mode = "library"
        view.forceActiveFocus()
    }
    function refreshPlayer() {
        var players = Mpris.players.values
        view.player = players.find(function(p) { return p.isPlaying }) || players.find(function(p) { return p.trackTitle }) || null
    }
    Timer { interval: 500; running: true; repeat: true; onTriggered: view.refreshPlayer() }
    Timer { id: searchDelay; interval: 250; onTriggered: if (view.query.trim()) { searchProcess.command = ["python3", Quickshell.shellPath("spotify_bridge.py"), "search", view.query.trim()]; searchProcess.running = true } }
    function search() { results = []; error = ""; searchDelay.restart() }
    function loadLibrary() {
        mode = "library"; selected = 0; error = ""
        // Keep the cached model on screen while Spotify refreshes it.
        if (playlists.length && saved.playlistsCacheVersion === 2 && Date.now() - saved.playlistsCachedAt < 60000) return
        if (!libraryProcess.running) libraryProcess.running = true
    }
    function loadQueue() { mode = "queue"; selected = 0; error = ""; queueProcess.command = ["python3", Quickshell.shellPath("spotify_bridge.py"), "queue"]; queueProcess.running = true }
    function loadRecent() { mode = "recent"; selected = 0; error = ""; recentProcess.command = ["python3", Quickshell.shellPath("spotify_bridge.py"), "recent"]; recentProcess.running = true }
    function openPlaylist(item) { mode = "playlist"; selected = 0; playlistId = item.id; playlistTitle = item.title; error = ""; playlistProcess.command = ["python3", Quickshell.shellPath("spotify_bridge.py"), "playlist", item.id]; playlistProcess.running = true }
    function play(item) {
        if (!item || playProcess.running) return
        error = ""
        playProcess.command = mode === "playlist"
            ? ["python3", Quickshell.shellPath("spotify_bridge.py"), "play-playlist", playlistId, String(view.selected)]
            : ["python3", Quickshell.shellPath("spotify_bridge.py"), "play", item.id]
        playProcess.running = true
    }
    function seekAt(fraction) {
        if (media.duration <= 0 || seekProcess.running) return
        seekProcess.command = ["python3", Quickshell.shellPath("spotify_bridge.py"), "seek", String(Math.round(Math.max(0, Math.min(1, fraction)) * media.duration))]
        seekProcess.running = true
    }
    function toggleShuffle() {
        if (shuffleProcess.running) return
        error = ""
        shuffleProcess.running = true
    }
    Process {
        id: searchProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try { var data = JSON.parse(text); view.results = Array.isArray(data) ? data : []; view.error = data.error || "" }
                catch (e) { view.error = "Resposta inválida da busca" }
            }
        }
        onExited: function(code, status) { if (code !== 0 && !view.error) view.error = "Falha na busca" }
    }
    Process {
        id: libraryProcess
        command: ["python3", Quickshell.shellPath("spotify_bridge.py"), "playlists"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    if (Array.isArray(data)) {
                        view.playlists = data
                        saved.playlistsJson = JSON.stringify(data)
                        saved.playlistsCachedAt = Date.now()
                        saved.playlistsCacheVersion = 2
                        saved.sync()
                    }
                    if (data.error && !view.playlists.length) view.error = data.error
                }
                catch (e) { view.error = "Resposta inválida da biblioteca" }
            }
        }
        onExited: function(code, status) { if (code !== 0 && !view.error) view.error = "Não foi possível carregar as playlists" }
    }
    Process {
        id: playlistProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try { var data = JSON.parse(text); view.tracks = Array.isArray(data) ? data : []; view.error = data.error || "" }
                catch (e) { view.error = "Resposta inválida da playlist" }
            }
        }
        onExited: function(code, status) { if (code !== 0 && !view.error) view.error = "Não foi possível carregar a playlist" }
    }
    Process {
        id: queueProcess
        stdout: StdioCollector { onStreamFinished: { try { var data = JSON.parse(text); view.queueItems = Array.isArray(data) ? data : []; view.error = data.error || "" } catch (e) { view.error = "Invalid queue response" } } }
        onExited: function(code, status) { if (code !== 0 && !view.error) view.error = "Could not load queue" }
    }
    Process {
        id: recentProcess
        stdout: StdioCollector { onStreamFinished: { try { var data = JSON.parse(text); view.recentItems = Array.isArray(data) ? data : []; view.error = data.error || "" } catch (e) { view.error = "Invalid recent response" } } }
        onExited: function(code, status) { if (code !== 0 && !view.error) view.error = "Could not load recently played" }
    }
    Process {
        id: playProcess
        stdout: StdioCollector { onStreamFinished: { try { var data = JSON.parse(text); view.error = data.error || "" } catch (e) {} } }
        onExited: function(code, status) { if (code !== 0 && !view.error) view.error = "Não foi possível tocar a faixa" }
    }
    Process { id: seekProcess }
    Process {
        id: shuffleProcess
        command: ["python3", Quickshell.shellPath("spotify_bridge.py"), "shuffle"]
        stdout: StdioCollector { onStreamFinished: { try { var data = JSON.parse(text); view.error = data.error || "" } catch (e) { view.error = "Resposta inválida do shuffle" } } }
        onExited: function(code, status) { if (code === 0) Qt.callLater(view.media.refresh); else if (!view.error) view.error = "Não foi possível alternar o shuffle" }
    }
    Keys.onPressed: function(event) {
        if (event.text === "?") { helpRequested() }
        else if (event.text === "b") { toggleButtons() }
        else if (event.text === "u") { loadQueue() }
        else if (event.text === "r") { loadRecent() }
        else if (event.text === "s") { toggleShuffle() }
        else if (event.text === "/") { mode = "search"; focusSearch() }
        else if (event.key === Qt.Key_Escape) back()
        else if (event.key === Qt.Key_Backspace && mode === "playlist") { loadLibrary(); event.accepted = true }
        else if (event.key === Qt.Key_Backspace) back()
        else if (event.key === Qt.Key_Space && player && player.canTogglePlaying) player.togglePlaying()
        else if (event.key === Qt.Key_Right && player && player.canGoNext) player.next()
        else if (event.key === Qt.Key_Left && player && player.canGoPrevious) player.previous()
        else if (event.key === Qt.Key_Q) closeRequested()
        else if (event.key === Qt.Key_Down) { var count = mode === "library" ? playlists.length : mode === "playlist" ? tracks.length : mode === "queue" ? queueItems.length : mode === "recent" ? recentItems.length : results.length; selected = Math.min(Math.max(0, count - 1), selected + 1); event.accepted = true }
        else if (event.key === Qt.Key_Up) { selected = Math.max(0, selected - 1); event.accepted = true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (mode === "library" && playlists[selected]) openPlaylist(playlists[selected]); else if (mode === "playlist" && tracks[selected]) play(tracks[selected]); else if (mode === "queue" && queueItems[selected]) play(queueItems[selected]); else if (mode === "recent" && recentItems[selected]) play(recentItems[selected]); else if (results[selected]) play(results[selected]); event.accepted = true }
        else return
        event.accepted = true
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 16
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Music"; color: theme.foreground; font.pixelSize: 20 }
            Item { Layout.fillWidth: true }
            Text { text: player ? player.identity : "No player"; color: theme.foreground; opacity: 0.55; font.pixelSize: 12 }
        }
        Rectangle {
            visible: view.searchVisible
            Layout.fillWidth: true; height: 42; radius: 6
            color: Qt.alpha(theme.foreground, 0.04); border.color: searchInput.activeFocus ? theme.accent : Qt.alpha(theme.foreground, 0.15)
            TextInput {
                id: searchInput; anchors.fill: parent; anchors.margins: 12
                color: theme.foreground; font.pixelSize: 14; clip: true
                text: view.query; onTextChanged: { view.query = text; view.selected = 0; view.search() }
                Keys.onEscapePressed: view.closeSearch()
                Text { visible: !searchInput.text; text: "Search Spotify tracks…"; color: theme.foreground; opacity: 0.5; font.pixelSize: 14 }
            }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                Text { text: view.mode === "library" ? "Your playlists" : view.mode === "playlist" ? "Tracks · " + playlistTitle : view.mode === "queue" ? "Up next" : view.mode === "recent" ? "Recently played" : "Search results"; color: theme.foreground; font.pixelSize: 16 }
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: 8
                    color: Qt.alpha(theme.foreground, 0.025); border.color: Qt.alpha(theme.foreground, 0.1)
                    ListView {
                        anchors.fill: parent; anchors.margins: 6; clip: true
                        model: view.mode === "library" ? view.playlists : view.mode === "playlist" ? view.tracks : view.mode === "queue" ? view.queueItems : view.mode === "recent" ? view.recentItems : view.results
                        currentIndex: view.selected
                        delegate: Rectangle {
                            required property int index; required property var modelData
                            width: ListView.view.width; height: 50; radius: 6; color: index === view.selected ? Qt.alpha(theme.accent, 0.13) : "transparent"
                            RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 12
                                Image { source: modelData.art || ""; visible: !!modelData.art; Layout.preferredWidth: 38; Layout.preferredHeight: 38; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                                ColumnLayout { Layout.fillWidth: true; spacing: 2
                                    Text { text: modelData.title; color: theme.foreground; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { text: modelData.subtitle; color: theme.foreground; opacity: 0.55; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                            }
                            MouseArea { anchors.fill: parent; onClicked: { view.selected = index; if (view.mode === "library") view.openPlaylist(modelData); else view.play(modelData) } }
                        }
                    }
                    Column { anchors.centerIn: parent; spacing: 8; visible: !view.loading && !view.error && ((view.mode === "library" ? view.playlists : view.mode === "playlist" ? view.tracks : view.mode === "queue" ? view.queueItems : view.mode === "recent" ? view.recentItems : view.results).length === 0)
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: view.mode === "library" ? "No playlists loaded" : view.mode === "queue" ? "Queue is empty" : view.mode === "recent" ? "No recent tracks" : "No results"; color: theme.foreground; font.pixelSize: 14 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Use / to search or try again"; color: theme.foreground; opacity: 0.55; font.pixelSize: 11 }
                    }
                    Column { anchors.centerIn: parent; spacing: 8; visible: !!view.error && !view.media.available
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Spotify is unavailable"; color: theme.accent; font.pixelSize: 14 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: view.error; color: theme.foreground; opacity: 0.65; font.pixelSize: 11; wrapMode: Text.Wrap; width: 360 }
                    }
                }
            }
            Rectangle {
                Layout.preferredWidth: 270; Layout.fillHeight: true; radius: 10
                color: Qt.alpha(theme.foreground, 0.035); border.color: Qt.alpha(theme.foreground, 0.12)
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 7
                    Text { text: "Now playing"; color: theme.foreground; opacity: 0.55; font.pixelSize: 11 }
                    Image {
                        visible: !!view.media.art
                        source: view.media.art
                        sourceSize.width: 420; sourceSize.height: 420
                        Layout.fillWidth: true; Layout.preferredHeight: view.searchVisible ? 170 : (view.showButtons ? 215 : 230)
                        fillMode: Image.PreserveAspectFit; asynchronous: true
                    }
                    Rectangle { visible: !view.media.art; Layout.fillWidth: true; Layout.preferredHeight: view.searchVisible ? 170 : (view.showButtons ? 215 : 230); color: Qt.alpha(theme.foreground, 0.06); radius: 6
                        Text { anchors.centerIn: parent; text: "♪"; color: theme.foreground; opacity: 0.35; font.pixelSize: 42 }
                    }
                    RowLayout {
                        visible: view.showButtons
                        Layout.fillWidth: true; spacing: 6
                        DashButton { Layout.fillWidth: true; theme: view.theme; text: "Library"; hint: "L"; focusPolicy: Qt.NoFocus; onClicked: view.loadLibrary() }
                        DashButton { Layout.fillWidth: true; theme: view.theme; text: "Search"; hint: "/"; focusPolicy: Qt.NoFocus; onClicked: { view.mode = "search"; view.focusSearch() } }
                        DashButton { Layout.fillWidth: true; theme: view.theme; text: "Queue"; hint: "U"; focusPolicy: Qt.NoFocus; onClicked: view.loadQueue() }
                        DashButton { Layout.fillWidth: true; theme: view.theme; text: "Recent"; hint: "R"; focusPolicy: Qt.NoFocus; onClicked: view.loadRecent() }
                    }
                    Text { Layout.fillWidth: true; text: view.media.title || "Nothing playing"; textFormat: Text.PlainText; elide: Text.ElideRight; color: theme.foreground; font.pixelSize: 16 }
                    Text { Layout.fillWidth: true; text: view.media.artist ? view.media.artist + (view.media.album ? " · " + view.media.album : "") : "Open a playlist to start"; textFormat: Text.PlainText; elide: Text.ElideRight; color: theme.foreground; opacity: 0.65; font.pixelSize: 12 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: view.media.formatTime(view.media.currentPosition()); color: theme.foreground; opacity: 0.55; font.pixelSize: 10; font.family: "monospace" }
                        Rectangle {
                            Layout.fillWidth: true; height: 5; radius: 3
                            color: Qt.alpha(theme.foreground, 0.13)
                            Rectangle {
                                width: parent.width * (view.media.duration > 0 ? Math.min(1, view.media.currentPosition() / view.media.duration) : 0)
                                height: parent.height; radius: 3; color: theme.accent
                            }
                            MouseArea { anchors.fill: parent; onClicked: view.seekAt(mouse.x / width) }
                        }
                        Text { text: view.media.formatTime(view.media.duration); color: theme.foreground; opacity: 0.55; font.pixelSize: 10; font.family: "monospace" }
                    }
                    Item { Layout.fillHeight: true }
                    GridLayout {
                        Layout.fillWidth: true; columns: 2; columnSpacing: 6; rowSpacing: 6
                        DashButton { Layout.fillWidth: true; theme: view.theme; text: "Previous"; hint: "←"; enabled: !!view.player && view.player.canGoPrevious; focusPolicy: Qt.NoFocus; onClicked: view.player.previous() }
                        DashButton { Layout.fillWidth: true; theme: view.theme; text: view.media.playing ? "Pause" : "Play"; hint: "Space"; enabled: !!view.player && view.player.canTogglePlaying; focusPolicy: Qt.NoFocus; onClicked: view.player.togglePlaying() }
                        DashButton { Layout.fillWidth: true; theme: view.theme; text: "Next"; hint: "→"; enabled: !!view.player && view.player.canGoNext; focusPolicy: Qt.NoFocus; onClicked: view.player.next() }
                        DashButton { Layout.fillWidth: true; theme: view.theme; text: view.media.shuffle ? "Shuffle on" : "Shuffle"; hint: "s"; focusPolicy: Qt.NoFocus; onClicked: view.toggleShuffle() }
                    }
                }
            }
        }
    }
    Component.onCompleted: {
        try {
            var cached = JSON.parse(saved.playlistsJson)
            if (saved.playlistsCacheVersion === 2 && Array.isArray(cached) && cached.length) {
                playlists = cached
            }
        } catch (e) {}
        // The cache makes the first frame useful; this refresh keeps it current.
        Qt.callLater(loadLibrary); Qt.callLater(refreshPlayer)
    }
}
