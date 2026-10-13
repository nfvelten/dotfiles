import QtQuick
import Quickshell
import Quickshell.Io

// State and controls for the background Radiola/mpv player.
Scope {
    id: store
    property bool active: false
    property bool available: false
    property bool playing: false
    property string title: ""
    property string feed: ""
    property real position: 0
    property real duration: 0
    property double syncedAt: 0
    property int clock: 0

    function currentPosition() {
        clock
        if (!playing) return position
        return Math.min(duration || position, position + Math.max(0, (Date.now() - syncedAt) / 1000))
    }
    function formatTime(value) {
        var seconds = Math.max(0, Math.floor(value || 0))
        return Math.floor(seconds / 60) + ":" + ("0" + (seconds % 60)).slice(-2)
    }
    function refresh() { if (!reader.running) reader.running = true }
    function toggle() { action.command = ["python3", Quickshell.shellPath("radiola_bridge.py"), "toggle"]; action.running = true }
    function stop() { action.command = ["python3", Quickshell.shellPath("radiola_bridge.py"), "stop"]; action.running = true }
    function open() { Quickshell.execDetached(["radiola-ui"]) }

    Timer { interval: 5000; running: store.active; repeat: true; onTriggered: store.refresh() }
    Timer { interval: 250; running: store.active && store.playing; repeat: true; onTriggered: store.clock++ }
    Timer { interval: 120; running: false; id: firstRefresh; onTriggered: if (store.active) store.refresh() }
    onActiveChanged: if (active) firstRefresh.restart()

    Process {
        id: reader
        command: ["python3", Quickshell.shellPath("radiola_bridge.py"), "current"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    store.available = !!data.available
                    if (data.available) {
                        store.playing = !!data.playing
                        store.title = data.title || ""
                        store.feed = data.feed || "Podcast"
                        store.position = Number(data.position || 0)
                        store.duration = Number(data.duration || 0)
                        store.syncedAt = Date.now()
                    }
                } catch (e) { store.available = false }
            }
        }
    }
    Process { id: action; onExited: { running = false; store.refresh() } }
}
