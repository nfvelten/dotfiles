import QtQuick
import Quickshell
import Quickshell.Io

// One resident yerbad (Rust) for every store. request() returns false while the daemon
// isn't running, so callers fall back to their Python bridge.
Scope {
    id: yerbad
    readonly property bool ready: daemon.running
    property int nextId: 1
    property var pending: ({})

    function request(cmd, callback) {
        if (!daemon.running) return false
        var id = nextId++
        pending[id] = callback
        daemon.write(JSON.stringify({id: id, cmd: cmd}) + "\n")
        return true
    }

    Process {
        id: daemon
        command: [Quickshell.env("HOME") + "/.local/bin/yerbad"]
        stdinEnabled: true
        running: true
        stdout: SplitParser {
            onRead: data => {
                var response
                try { response = JSON.parse(data) } catch (e) { return }
                var callback = yerbad.pending[response.id]
                delete yerbad.pending[response.id]
                if (callback) callback(response.error || "", response.result)
            }
        }
        // Fail whatever was in flight, then retry after a pause instead of crash-looping.
        onExited: {
            var waiting = yerbad.pending
            yerbad.pending = {}
            for (var id in waiting) waiting[id]("yerbad exited", undefined)
            restart.restart()
        }
    }
    Timer { id: restart; interval: 10000; onTriggered: daemon.running = true }
}
