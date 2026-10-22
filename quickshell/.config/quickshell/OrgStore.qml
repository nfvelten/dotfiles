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
    property var events: []
    property string calendarError: ""
    property string month: Qt.formatDate(new Date(), "yyyy-MM")
    property string loadedMonth: ""
    readonly property bool calendarLoading: calendarProcess.running
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
    // khal takes ~5s: refresh in the background instead of on every dock open.
    Timer { interval: 900000; running: true; repeat: true; triggeredOnStart: true; onTriggered: store.refreshCalendar() }
    function refreshCalendar() {
        if (calendarProcess.running) return
        // Keep the current month's events visible while khal (~5s) refreshes them.
        if (loadedMonth !== month) events = []
        loadedMonth = month
        calendarError = ""
        var parts = month.split("-")
        var first = new Date(Number(parts[0]), Number(parts[1]) - 1, 1)
        var last = new Date(Number(parts[0]), Number(parts[1]), 0)
        calendarProcess.command = ["bash", Quickshell.shellPath("almanac/khal-events"), Qt.formatDate(first, "yyyy-MM-dd"), Qt.formatDate(last, "yyyy-MM-dd")]
        calendarProcess.running = true
    }
    onMonthChanged: refreshCalendar()
    Process {
        id: calendarProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (store.loadedMonth !== store.month) return
                try { store.events = JSON.parse(text) }
                catch (e) { store.calendarError = "Agenda unavailable" }
            }
        }
        onExited: function(code, status) {
            if (code !== 0) store.calendarError = "Could not query khal"
            if (store.loadedMonth !== store.month) store.refreshCalendar()
        }
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
