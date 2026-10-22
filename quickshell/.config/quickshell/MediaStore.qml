import QtQuick
import Quickshell
import Quickshell.Io

// Single source of truth for the active Spotify playback state.
Scope {
    id: store
    property bool available: false
    property bool playing: false
    property bool shuffle: false
    property string title: ""
    property string artist: ""
    property string album: ""
    property string art: ""
    property real position: 0
    property real duration: 0
    property double syncedAt: 0
    property int clock: 0
    property string error: ""
    // The dock is the only consumer of this state.  Pausing the pollers while it
    // is hidden avoids waking Python and the Spotify API every few seconds.
    property bool active: false

    function currentPosition() {
        clock
        if (!playing) return position
        return Math.min(duration || position, position + Math.max(0, Date.now() - syncedAt))
    }
    function formatTime(value) {
        var seconds = Math.max(0, Math.floor(value / 1000))
        return Math.floor(seconds / 60) + ":" + ("0" + (seconds % 60)).slice(-2)
    }
    // Shared yerbad first (keeps the Web API connection open); Python bridge as fallback.
    property QtObject yerbad: null
    property bool daemonBusy: false
    function refresh() {
        if (daemonBusy || current.running) return
        var asked = yerbad && yerbad.request("spotify.current", function(err, result) {
            store.daemonBusy = false
            store.apply(err ? {error: err} : result)
        })
        if (asked) daemonBusy = true
        else current.running = true
    }
    function apply(data) {
        store.error = data.error || ""
        store.available = !!data.available
        if (data.available) {
            store.playing = !!data.playing
            store.shuffle = !!data.shuffle
            store.title = data.title || ""
            store.artist = data.artist || ""
            store.album = data.album || ""
            store.art = data.art || ""
            store.position = Number(data.position || 0)
            store.duration = Number(data.duration || 0)
            store.syncedAt = Date.now()
        }
    }
    // Spotify rate-limits frequent /me/player requests; 10s is enough for the
    // dashboard while avoiding 429 responses during normal navigation.
    Timer { interval: 10000; running: store.active; repeat: true; onTriggered: store.refresh() }
    Timer { id: firstRefresh; interval: 180; repeat: false; onTriggered: if (store.active) store.refresh() }
    Timer { interval: 250; running: store.active && store.playing; repeat: true; onTriggered: store.clock++ }
    Process {
        id: current
        command: ["python3", Quickshell.shellPath("spotify_bridge.py"), "current"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { store.apply(JSON.parse(text)) } catch (e) { store.error = "Invalid Spotify state" }
            }
        }
    }
    onActiveChanged: if (active) firstRefresh.restart()
}
