import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

Scope {
    id: store
    property QtObject yerbad: null
    TmuxStore { id: tmuxStore; yerbad: store.yerbad }
    property alias tmux: tmuxStore
    property var entries: []
    property var home: ({tasks: [], taskCount: 0, recent: []})
    CalendarStore { id: calendarStore }
    property alias calendar: calendarStore
    property alias events: calendarStore.events
    property alias calendarError: calendarStore.error
    property alias month: calendarStore.month
    readonly property bool calendarLoading: calendarStore.loading
    property string error: ""
    property string message: ""
    property string wantedQuery: ""
    property string activeQuery: ""
    property string operation: ""
    property bool searchBusy: false
    readonly property bool loading: (searchBusy && !!wantedQuery) || debounce.running
    readonly property bool busy: writer.running
    readonly property string helper: Quickshell.shellPath("org_bridge.py")
    readonly property var pins: JSON.parse(saved.pinsJson)
    signal opened()
    signal captured()
    Settings {
        id: saved
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/yerba-shell.ini"
        category: "org"
        property string pinsJson: "[]"
    }
    function pinned(item) { return pins.some(function(p) { return p.orgPath === item.orgPath && p.orgLine === item.orgLine }) }
    function togglePin(item) {
        var list = pins.filter(function(p) { return !(p.orgPath === item.orgPath && p.orgLine === item.orgLine) })
        if (list.length === pins.length) list.unshift(item)
        saved.pinsJson = JSON.stringify(list.slice(0, 12))
        saved.sync()
        message = pinned(item) ? "Note pinned" : "Note unpinned"
    }
    function search(query) {
        wantedQuery = query.trim()
        entries = []
        if (wantedQuery) debounce.restart()
        else debounce.stop()
    }
    // Shared yerbad first (~11 ms); Python bridge as fallback.
    property bool homeBusy: false
    function refresh() {
        tmuxStore.refresh()
        if (homeBusy || homeProcess.running) return
        var asked = yerbad && yerbad.request("org.home", function(err, result) {
            store.homeBusy = false
            store.applyHome(err ? {error: err} : result)
        })
        if (asked) homeBusy = true
        else homeProcess.running = true
    }
    function applyHome(data) {
        if (data.error) store.error = data.error
        else store.home = data
    }
    function run(action, args) {
        if (writer.running) return
        error = ""; message = ""; operation = action
        writer.command = ["python3", helper, action].concat(args || [])
        writer.running = true
    }
    function dispatchSearch() {
        if (searchBusy || !wantedQuery) return
        activeQuery = wantedQuery
        searchBusy = true
        searchProcess.write(JSON.stringify(activeQuery) + "\n")
    }
    Timer {
        id: debounce
        interval: 180
        onTriggered: {
            if (store.searchBusy || !store.wantedQuery) return
            if (!searchProcess.running) searchProcess.running = true
            else store.dispatchSearch()
        }
    }
    Process {
        id: searchProcess
        command: ["python3", store.helper, "serve-search"]
        stdinEnabled: true
        onStarted: store.dispatchSearch()
        stdout: SplitParser {
            onRead: data => {
                store.searchBusy = false
                try {
                    var response = JSON.parse(data)
                    if (response.query === store.wantedQuery) {
                        store.entries = response.entries
                        store.error = response.error || ""
                    }
                } catch (e) { store.error = "Could not search notes" }
                if (store.activeQuery !== store.wantedQuery && store.wantedQuery) debounce.restart()
            }
        }
        onExited: function(code, status) {
            store.searchBusy = false
            if (code !== 0) store.error = "Note search failed"
            // The next query restarts the worker; avoid an automatic crash loop.
        }
    }
    Process {
        id: homeProcess
        command: ["python3", store.helper, "home"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { store.applyHome(JSON.parse(text)) } catch (e) { store.error = "Could not load Org summary" }
            }
        }
    }
    Process {
        id: writer
        property bool succeeded: false
        onStarted: succeeded = false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    writer.succeeded = data.ok === true
                    if (data.error) store.error = data.error
                } catch (e) { store.error = "Invalid response from Org bridge" }
            }
        }
        onExited: function(code, status) {
            if (code !== 0 || !succeeded) {
                if (!store.error) store.error = "Could not finish; check Emacs"
                return
            }
            if (store.operation === "open" || store.operation === "today") store.opened()
            if (store.operation === "capture") { store.message = "Task saved to today's note"; store.refresh(); store.captured() }
            if (store.operation === "link") store.message = "Link Org copiado"
        }
    }
}
