import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: store
    property var items: []
    property double savedAt: 0
    property string error: ""
    property bool active: false
    property var detail: null
    property bool detailLoading: detailReader.running
    readonly property bool loading: reader.running

    Timer { interval: 300000; running: store.active; repeat: true; onTriggered: store.refresh() }
    onActiveChanged: if (active) refresh()
    function refresh() { if (!reader.running) reader.running = true }
    function loadDetail(itemId) {
        detail = null
        detailReader.command = ["python3", Quickshell.shellPath("azure_bridge.py"), "detail:" + itemId]
        detailReader.running = true
    }
    Process {
        id: reader
        command: ["python3", Quickshell.shellPath("azure_bridge.py"), "mine"]
        running: store.active
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    if (Array.isArray(data.items)) store.items = data.items
                    store.savedAt = Number(data.savedAt || 0)
                    store.error = data.error || ""
                } catch (e) { store.error = "Could not read Azure Boards" }
            }
        }
        onExited: function(code) { if (code !== 0 && !store.error) store.error = "Azure Boards unavailable" }
    }
    Process {
        id: detailReader
        stdout: StdioCollector {
            onStreamFinished: {
                try { store.detail = JSON.parse(text) }
                catch (e) { store.detail = {error: "Could not read Azure item details"} }
            }
        }
        onExited: function(code) { if (code !== 0 && !store.detail) store.detail = {error: "Azure Boards unavailable"} }
    }
}
