import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import "CalendarLogic.js" as Logic

Scope {
    id: store
    property string settingsPath: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/yerba-shell.ini"
    property bool automatic: true
    property bool browsing: false
    property string month: Qt.formatDate(new Date(), "yyyy-MM")
    property var events: []
    property var agenda: []
    property string error: ""
    property string agendaError: ""
    property double now: Date.now()
    property double fetchedAt: 0
    property double attemptedAt: 0
    property string today: Logic.dateKey(new Date())
    property var openEvent: null
    property var syncStatus: ({sources: {}})
    property string syncError: ""
    readonly property bool loading: monthProcess.running
    readonly property bool syncing: syncProcess.running || (!!syncStatus.running && now - syncStatus.startedAt < 1800000)
    readonly property var sources: Object.keys(syncStatus.sources || {}).map(function(k) { return store.syncStatus.sources[k] })
    readonly property var config: ({enabled: saved.enabled, allCalendars: saved.allCalendars, minutes: saved.minutes, atStart: saved.atStart,
        keywords: saved.keywords, calendars: parse(saved.calendarsJson, []), events: parse(saved.eventsJson, {})})
    readonly property var upcoming: Logic.upcoming(agenda, now, config)
    readonly property string syncSummary: {
        if (syncError) return syncError
        if (syncing) return "Sincronizando fontes…"
        if (!syncStatus.finishedAt) return "No sync recorded yet"
        var failed = sources.filter(function(s) { return !!s.error }).length
        var when = Qt.formatDateTime(new Date(syncStatus.finishedAt), "dd/MM HH:mm")
        return (failed ? failed + " source(s) failed · tried " : "Updated ") + when
    }
    signal eventRequested(var item)
    Settings {
        id: saved
        location: store.settingsPath
        category: "calendar"
        property bool enabled: true
        property bool allCalendars: false
        property int minutes: 15
        property bool atStart: false
        property string keywords: ""
        property string calendarsJson: "[]"
        property string eventsJson: "{}"
        property string reminderStateJson: "{}"
    }
    function parse(text, fallback) { try { return JSON.parse(text) } catch (e) { return fallback } }
    function labelFor(name) {
        var labels = {personal:"Personal",work:"Work",holidays:"Holidays",sports:"Sports",sports_motorsport:"Motorsport",sports_golf:"Golf",sports_tennis:"Tennis",sports_football:"Football",sports_ucl:"Champions League",sports_pl:"Premier League",sports_laliga:"La Liga",sports_seriea:"Serie A",sports_bundesliga:"Bundesliga",sports_nba:"NBA",sports_ufc:"UFC",sports_chess:"Chess",sports_esports:"Esports",sports_mlb:"MLB"}
        return labels[name] || name
    }
    function startOf(e) { return Logic.startOf(e) }
    function endOf(e) { return Logic.endOf(e) }
    function countdown(e) { return Logic.countdown(e, now) }
    function key(e) { return Logic.key(e) }
    function favorite(e) { return Logic.favorite(e, config) }
    function minutesFor(e) { return Logic.minutesFor(e, config) }
    function cancelled(e) { return Logic.cancelled(e) }
    function eventUrl(e) { return Logic.eventUrl(e) }
    function toggleEnabled() { saved.enabled = !saved.enabled; saved.sync() }
    function setKeywords(text) { saved.keywords = text.trim().slice(0, 500); saved.sync(); tick() }
    function setMinutes(value) { if ([0,5,10,15,30,60].indexOf(value) < 0) return; saved.minutes = value; saved.sync() }
    function cycleMinutes() { var choices = [5,10,15,30,60]; setMinutes(choices[(choices.indexOf(saved.minutes) + 1) % choices.length]) }
    function toggleAllCalendars() { saved.allCalendars = !saved.allCalendars; saved.sync() }
    function toggleAtStart() { saved.atStart = !saved.atStart; saved.sync() }
    function followCalendar(name) {
        if (!name) return
        var list = config.calendars.slice(), i = list.indexOf(name)
        if (i >= 0) list.splice(i, 1); else list.push(name)
        saved.calendarsJson = JSON.stringify(list); saved.sync(); tick()
    }
    function updateEvent(e, field, value) {
        var entries = parse(saved.eventsJson, {}), id = key(e)
        entries[id] = entries[id] || {}
        entries[id][field] = value
        entries[id].expires = (isFinite(endOf(e)) ? endOf(e) : now + 86400000) + 86400000
        Object.keys(entries).forEach(function(k) { if (entries[k].expires < store.now) delete entries[k] })
        saved.eventsJson = JSON.stringify(entries); saved.sync(); tick()
    }
    function toggleFavorite(e) { updateEvent(e, "favorite", !(config.events[key(e)] || {}).favorite) }
    function cycleReminder(e) {
        var choices = [-1,saved.minutes,5,10,15,30,60,0].filter(function(v,i,a) { return a.indexOf(v) === i }), current = minutesFor(e)
        updateEvent(e, "minutes", choices[(choices.indexOf(current) + 1) % choices.length])
    }
    function reminderLabel(e) {
        var minutes = minutesFor(e)
        return minutes < 0 ? "Reminder off" : minutes === 0 ? "Reminder at start" : "Reminder " + minutes + " min before"
    }
    function requestOpen(e) { openEvent = e; eventRequested(e) }
    function snooze(e) {
        var state = parse(saved.reminderStateJson, {})
        state.snoozes = state.snoozes || {}
        state.snoozes[key(e)] = Date.now() + 5 * 60000
        saved.reminderStateJson = JSON.stringify(state); saved.sync()
    }
    function tick() {
        now = Date.now()
        syncFile.reload()
        var day = Logic.dateKey(new Date(now))
        if (day !== today) { today = day; if (!browsing) month = today.slice(0,7); refreshAgenda() }
        if (automatic && now - attemptedAt >= 900000) refreshAgenda()
        if (!fetchedAt || now - fetchedAt > 1800000) return
        var result = Logic.plan(agenda, config, parse(saved.reminderStateJson, {}), now)
        var encoded = JSON.stringify(result.state)
        if (encoded !== saved.reminderStateJson) { saved.reminderStateJson = encoded; saved.sync() }
        result.notices.forEach(function(n) { store.notify(n.event, n.snoozed) })
    }
    function notify(e, snoozed) {
        var remaining = Math.max(0, Math.ceil((startOf(e) - now) / 60000))
        var title = e.title + (remaining ? " starts in " + remaining + " min" : " · starting now")
        var body = e.time + " · " + labelFor(e.calendar) + (snoozed ? " · snoozed" : "")
        var process = noticeComponent.createObject(store, {item: e, command: ["notify-send", "-a", "Calendar",
            "-i", "x-office-calendar", "-t", "15000", "--action=default=Open event", "--action=snooze=Snooze 5 min", "--", title, body]})
        process.running = true
    }
    Component {
        id: noticeComponent
        Process {
            id: notice
            property var item
            stdout: SplitParser {
                onRead: data => { if (data.trim() === "default") store.requestOpen(notice.item); else if (data.trim() === "snooze") store.snooze(notice.item) }
            }
            onExited: destroy()
        }
    }
    function refreshAgenda() {
        if (agendaProcess.running || !automatic) return
        attemptedAt = Date.now()
        var first = new Date(); first.setDate(first.getDate() - 1)
        var last = new Date(); last.setDate(last.getDate() + 8)
        agendaProcess.command = ["bash", Quickshell.shellPath("almanac/khal-events"), Logic.dateKey(first), Logic.dateKey(last)]
        agendaProcess.running = true
    }
    function refreshMonth() {
        if (monthProcess.running || !automatic) return
        var p = month.split("-"), first = new Date(Number(p[0]), Number(p[1])-1, 1)
        first.setDate(first.getDate() - first.getDay())
        var last = new Date(first); last.setDate(last.getDate()+41)
        monthProcess.requestedMonth = month
        monthProcess.command = ["bash", Quickshell.shellPath("almanac/khal-events"), Logic.dateKey(first), Logic.dateKey(last)]
        monthProcess.running = true
    }
    function refresh() { refreshAgenda(); refreshMonth() }
    function synchronize() {
        if (syncing) return
        syncError = ""; syncProcess.running = true
    }
    onMonthChanged: refreshMonth()
    Component.onCompleted: { if (automatic) refresh() }
    Timer { interval: 30000; running: store.automatic; repeat: true; onTriggered: store.tick() }
    Timer { interval: 900000; running: store.automatic; repeat: true; onTriggered: store.refreshMonth() }
    Process {
        id: agendaProcess
        property string output: ""
        property int code: -1
        property bool streamDone: false
        onStarted: { output = ""; code = -1; streamDone = false }
        stdout: StdioCollector { onStreamFinished: { agendaProcess.output = text; agendaProcess.streamDone = true; agendaProcess.finish() } }
        // stdout can finish before or after the exit signal; parse once both are in.
        onExited: function(exitCode) { code = exitCode; finish() }
        function finish() {
            if (!streamDone || code < 0) return
            if (code !== 0) { store.agendaError = "Could not read the agenda; keeping the last result"; return }
            var data = store.parse(output, null)
            if (!Array.isArray(data)) { store.agendaError = "Invalid agenda response"; return }
            store.agenda = data; store.fetchedAt = Date.now(); store.agendaError = ""; store.tick()
        }
    }
    Process {
        id: monthProcess
        property string requestedMonth: ""
        property string output: ""
        property int code: -1
        property bool streamDone: false
        onStarted: { output = ""; code = -1; streamDone = false }
        stdout: StdioCollector { onStreamFinished: { monthProcess.output = text; monthProcess.streamDone = true; monthProcess.finish() } }
        onExited: function(exitCode) { code = exitCode; finish() }
        function finish() {
            if (!streamDone || code < 0) return
            if (requestedMonth !== store.month) { store.refreshMonth(); return }
            var data = store.parse(output, null)
            if (code !== 0 || !Array.isArray(data)) { store.error = "Could not read the calendar; keeping previous data"; return }
            store.events = data; store.error = ""
        }
    }
    Process {
        id: syncProcess
        command: ["systemctl", "--user", "start", "vdirsyncer.service"]
        onExited: function(code) { if (code !== 0) store.syncError = "Sync partly failed; see sources"; syncFile.reload(); store.refresh() }
    }
    FileView {
        id: syncFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/yerba/calendar-sync.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var status = store.parse(text(), {sources:{}})
            var changed = status.finishedAt && status.finishedAt !== store.syncStatus.finishedAt
            store.syncStatus = status
            if (changed) { store.syncError = ""; store.refresh() }
        }
    }
    IpcHandler {
        target: "calendar"
        function status(): string { return JSON.stringify({events:store.agenda.length, enabled:saved.enabled, minutes:saved.minutes,
            allCalendars:saved.allCalendars, calendars:store.config.calendars, keywords:saved.keywords, fetchedAt:store.fetchedAt, error:store.agendaError, sync:store.syncSummary}) }
        function setKeywords(value: string) { store.setKeywords(value) }
        function setMinutes(value: int) { store.setMinutes(value) }
        function follow(name: string) { store.followCalendar(name) }
        function refresh() { store.refresh() }
        function sync() { store.synchronize() }
    }
}
