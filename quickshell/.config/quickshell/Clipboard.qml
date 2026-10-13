import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: store
    property var entries: []
    property string error: ""
    readonly property bool loading: listing.running
    readonly property bool copying: copier.running
    readonly property string helper: Quickshell.shellPath("clipboard.py")
    property string previewId: ""
    property string wantedPreview: ""
    property string activePreview: ""
    property string previewText: ""
    property string previewImage: ""
    property string previewMime: ""
    readonly property bool previewLoading: wantedPreview !== previewId
    function requestPreview(id) {
        if (wantedPreview === id) return
        wantedPreview = id
        previewText = ""
        previewImage = ""
        activePreview = ""
        if (!id) { previewId = ""; return }
        previewDelay.restart()
    }
    Timer {
        id: previewDelay
        interval: 80
        onTriggered: {
            if (!store.wantedPreview || previewer.running || store.activePreview === store.wantedPreview) return
            store.activePreview = store.wantedPreview
            previewer.command = ["python3", store.helper, "preview", store.wantedPreview]
            previewer.running = true
        }
    }
    Process {
        id: previewer
        onExited: { if (store.activePreview !== store.wantedPreview) previewDelay.restart() }
        stdout: StdioCollector {
            onStreamFinished: {
                if (store.activePreview !== store.wantedPreview) return
                try {
                    var data = JSON.parse(text)
                    store.previewId = store.activePreview
                    store.previewText = data.text || data.error || ""
                    store.previewImage = data.image || ""
                    store.previewMime = data.mime || ""
                } catch (e) { store.previewId = store.activePreview; store.previewText = "Preview unavailable" }
            }
        }
    }
    signal copied()
    function refresh() {
        if (listing.running) return
        error = ""
        listing.running = true
    }
    function copyEntry(id) {
        if (copier.running) return
        error = ""
        copier.command = ["python3", helper, "copy", id]
        copier.running = true
    }
    Process {
        id: listing
        command: ["python3", store.helper, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    if (Array.isArray(data)) store.entries = data
                    else { store.entries = []; store.error = data.error || "Could not load clipboard history" }
                } catch (e) { store.entries = []; store.error = "Could not load clipboard history" }
            }
        }
    }
    Process {
        id: copier
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var result = JSON.parse(text)
                    if (result.ok) store.copied()
                    else store.error = result.error || "Could not copy this entry"
                } catch (e) { store.error = "Could not copy this entry" }
            }
        }
    }
}
