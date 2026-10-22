import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Actions.js" as Actions

PanelWindow {
    id: panel
    signal closeRequested()
    signal toggleTopBarRequested()
    required property bool showTopBar
    required property QtObject buttonPreferences
    required property string time
    required property QtObject theme
    required property QtObject org
    required property QtObject clipboard
    required property QtObject notifications
    property QtObject meeting: null
    property QtObject yerbad: null
    // password-store entry names only (via yerbad pass.list); secrets are copied by desktop-pass.
    property var passEntries: []
    property bool passLoading: false
    function loadPasswords() {
        if (passLoading || !yerbad) return
        passLoading = yerbad.request("pass.list", function(err, result) {
            panel.passLoading = false
            panel.passEntries = err ? [] : result
        })
        // Daemon (re)starting: try again shortly while the page is open.
        if (!passLoading) passRetry.restart()
    }
    Timer { id: passRetry; interval: 1000; onTriggered: { if (panel.isOpen && panel.route === "passwords") panel.loadPasswords() } }
    // Field names of one entry, sent back by `desktop-pass fields` after decrypting (values stay there).
    property string passFieldsFor: ""
    property var passFieldNames: []
    // Enter on an entry: show its fields in place. desktop-pass decrypts (pinentry only if the
    // passphrase isn't cached) and answers through the passFields IPC call.
    function openPassFields(entry) {
        passFieldsFor = ""
        passFieldNames = []
        contextItem = {title: entry.split("/").pop(), passEntry: entry}
        selected = 0
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/desktop-pass", "fields", entry])
    }
    function showPassFields(entry, names) {
        // Reopened after pinentry (or opened from outside): rebuild the page around the entry.
        if (!(route === "passwords" && contextItem && contextItem.passEntry === entry)) {
            navigate("passwords")
            contextItem = {title: entry.split("/").pop(), passEntry: entry}
        }
        passFieldsFor = entry
        passFieldNames = names
        selected = 0
    }
    function passFieldTitle(name) {
        if (name === "password") return "Copy password"
        if (name === "username") return "Copy username"
        if (name === "notes") return "Copy notes"
        return "Copy " + name.slice(4)
    }
    function copyPass(entry, field) {
        panel.closeRequested()
        // Let the dock release keyboard focus before pinentry may ask for the GPG passphrase.
        Quickshell.execDetached(["bash", "-c", "sleep 0.3; exec \"$0\" copy \"$1\" \"$2\"", Quickshell.env("HOME") + "/.local/bin/desktop-pass", entry, field])
    }
    required property QtObject feed
    required property QtObject media
    property bool isOpen: false
    property string query: ""
    property string route: "main"
    property var pending: null
    property var contextItem: null
    property string captureText: ""
    readonly property bool dashboardVisible: route === "main" && !query.trim() && !contextItem && !pending
    readonly property bool fullView: isFullViewRoute(route)
    function isFullViewRoute(value) {
        return ["tmux", "controls", "audio", "bluetooth", "network", "calendar", "media", "boards", "preferences", "themes"].indexOf(value) >= 0
    }
    function dockHeight(containerHeight) {
        var available = containerHeight - (panel.showTopBar ? 48 : 132)
        if (panel.dashboardVisible) {
            var contentHeight = dashboardLoader.item ? dashboardLoader.item.implicitHeight : 200
            return Math.min(available, Math.min(610, contentHeight + 102))
        }
        if (panel.route === "boards") {
            var detail = boardsLoader.item && boardsLoader.item.detailMode
            var listHeight = 180 + Math.max(1, panel.feed.azure.items.length) * 58
            return Math.min(available, detail ? 610 : Math.min(610, listHeight))
        }
        if (panel.fullView) return Math.min(available, 610)
        if (panel.route === "capture") return Math.min(available, 290)
        if (panel.route === "clipboard") return Math.min(available, 440)
        return Math.min(available, 132 + Math.min(5, Math.max(1, panel.rows.length)) * 48)
    }
    function searchPlaceholder() {
        if (search.activeFocus) {
            if (["audio", "bluetooth", "network", "controls"].indexOf(panel.route) >= 0)
                return panel.route === "audio" ? "Audio" : panel.route === "bluetooth" ? "Bluetooth" : panel.route === "network" ? "Network" : "System controls"
            if (panel.route === "notes") return "Search Org notes…"
            if (panel.route === "clipboard") return "Search clipboard…"
            if (panel.route === "notifications") return "Search notifications…"
            if (panel.route === "passwords") return "Search passwords…"
            return "Notes, apps and actions…"
        }
        var labels = {
            notes: "Search Org notes", clipboard: "Search clipboard", applications: "Search apps",
            tmux: "Filter tmux windows", audio: "Audio", bluetooth: "Bluetooth",
            network: "Network", controls: "System controls", notifications: "Search notifications", passwords: "Search passwords"
        }
        return "/  " + (labels[panel.route] || "Search notes, apps and actions")
    }
    function sectionTitle() {
        if (panel.route === "tmux") return "tmux sessions and windows"
        if (panel.contextItem) return "Actions · " + panel.contextItem.title.replace(/^● /, "")
        if (panel.route === "notes") return "Org notes"
        if (panel.pending) return "Confirmation"
        if (panel.route === "clipboard") return "Clipboard"
        if (panel.route === "applications") return "Applications"
        if (panel.route === "notifications") return "Notifications · " + notifications.historyEntries.length + " saved"
        if (panel.route === "passwords") return "Passwords · " + panel.passEntries.length + " entries"
        if (panel.route === "main" && panel.query.trim()) return "Apps · Actions · Agents · Notes"
        return "Commands"
    }
    function footerHint() {
        if (panel.route === "calendar") return "hjkl day/week    [ ] month    g today    J K event    ? keys"
        if (panel.route === "media") return "↑ ↓ select    Enter play    Space play/pause    Tab player    / search    ? keys"
        if (panel.route === "boards") return "↑ ↓ select    Enter/o details    r refresh    Esc back"
        if (panel.route === "tmux") return "j k select    Enter/e resume in Super + C    ? keys"
        if (panel.route === "notifications") return "j k select    Enter open/copy    Ctrl+K actions    / search    ? keys"
        if (panel.route === "passwords") return panel.contextItem ? "↑ ↓ select    Enter copy    Esc back to list" : "↑ ↓ select    Enter show fields    Esc back"
        if (panel.route === "preferences") return "j k select    Enter toggle    ? keys    Esc back"
        if (panel.route === "themes") return "↑ ↓ select    Enter apply    Esc back"
        if (["controls", "audio", "bluetooth", "network"].indexOf(panel.route) >= 0)
            return (controlsLoader.item && controlsLoader.item.message) || "j k item    Enter toggle    - + volume    ? keys"
        if (panel.org.tmux.error) return panel.org.tmux.error
        if (panel.org.tmux.busy) return "Resuming session…"
        if (panel.dashboardVisible && !panel.org.error && !panel.org.message)
            return search.activeFocus ? "Type to search · Esc keys" : "/ search    ? keys    q close"
        if (panel.route === "capture" && !panel.org.error && !panel.org.busy) return "Enter save    Esc back"
        if (panel.org.busy) return "Please wait…"
        if (panel.org.error) return panel.org.error
        if (panel.org.message) return panel.org.message
        if (search.activeFocus) return "↑ ↓ select    Enter open    Esc keys"
        return "j k select    Enter " + (panel.route === "clipboard" ? "copy" : "open") + "    / search    Backspace back    ? keys"
    }
    function openTmuxItem(item) {
        panel.route = "tmux"
        panel.query = ""
        panel.selected = Math.max(0, panel.rows.findIndex(function(row) { return row.tmuxWindow === item.tmuxWindow }))
    }
    function itemKind(item) {
        if (item.tmuxWindow) return "tmux"
        if (item.orgPath) return "Org"
        if (item.clipboardId) return item.kind
        if (item.historyKey) return item.historyApp
        if (item.passEntry) return "Password"
        if (item.desktopId) return "App"
        if (item.route) return "Menu"
        return "Action"
    }
    function emptyMessage() {
        if (panel.route === "passwords") return panel.passLoading ? "Loading passwords…" : "No passwords found"
        if (panel.route === "clipboard" && panel.clipboard.loading) return "Loading clipboard…"
        if (panel.route === "clipboard" && panel.clipboard.error) return panel.clipboard.error
        if (panel.org.loading) return "Searching notes…"
        if (panel.route === "tmux") return panel.org.tmux.loading ? "Loading sessions…" : "No open tmux sessions"
        return "No results"
    }
    function homeRows() {
        if (!org) return []
        var recent = org.pins.concat(org.home.recent.filter(function(r) { return !org.pins.some(function(p) { return p.orgPath === r.orgPath }) })).slice(0, 3)
        var rows = recent.map(function(r) {
            return Object.assign({}, r, {group: "CONTINUAR", label: "Org", hint: org.pinned(r) ? "pinned" : "recently edited"})
        })
        rows.push({title: "Today's note", hint: org.home.taskCount + " open", label: "Today", group: "HOJE", orgAction: "today"})
        org.home.tasks.slice(0, 2).forEach(function(r) { rows.push(Object.assign({}, r, {group: "HOJE", label: "□", hint: "task"})) })
        rows.push({title: "Capture task", hint: "daily note", label: "+", group: "ATALHOS", route: "capture"})
        rows.push({title: "Audio", hint: "volume and devices", label: "c", group: "ATALHOS", route: "audio"})
        rows.push({title: "Bluetooth", hint: "devices", label: "B", group: "ATALHOS", route: "bluetooth"})
        rows.push({title: "Network", hint: "Wi-Fi and Ethernet", label: "w", group: "ATALHOS", route: "network"})
        return rows
    }
    onQueryChanged: {
        // "notes: x", "clip: x", "tmux: x", "apps: x", "notif: x" jump to that page with x as the query.
        var prefix = route === "main" ? /^(notes|clip|tmux|apps|notif|pass):\s*(.*)$/i.exec(query) : null
        if (prefix) {
            var target = {notes: "notes", clip: "clipboard", tmux: "tmux", apps: "applications", notif: "notifications", pass: "passwords"}[prefix[1].toLowerCase()]
            var rest = prefix[2]
            navigate(target)
            query = rest
            Qt.callLater(focusSearch)
            return
        }
        if (org) org.search((route === "main" || route === "notes") ? query : ""); copyCalcWhenReady = false; calcDebounce.restart()
    }
    // Calculator: qalc answers math-looking queries ("15*1.08", "10 usd to brl", "sqrt(2)").
    // Plain words never reach it, since qalc reads them as units ("hello" -> e·B·h·L²).
    property string calcResult: ""
    property string calcFor: ""
    property bool copyCalcWhenReady: false
    function copyCalc(value) { copyCalcWhenReady = false; Quickshell.execDetached(["wl-copy", value]); panel.closeRequested() }
    function looksLikeMath(text) {
        var t = text.trim()
        var start = /^([-+(.\d]|(sqrt|cbrt|sin|cos|tan|log|ln|abs|round|floor|ceil)\s*\()/i.test(t)
        return start && /[-+*\/^%×÷()]|\s(to|in)\s/i.test(t)
    }
    Timer {
        id: calcDebounce
        interval: 120
        onTriggered: {
            panel.calcResult = ""
            if (panel.route !== "main" || !panel.looksLikeMath(panel.query)) return
            calcProcess.running = false
            calcProcess.expression = panel.query.trim()
            calcProcess.command = ["qalc", "-t", "-set", "max decimals 4", calcProcess.expression]
            calcProcess.running = true
        }
    }
    Process {
        id: calcProcess
        property string expression: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n").filter(function(l) { return l && !/^(error|warning)/i.test(l) })
                var result = lines.length ? lines[lines.length - 1].trim() : ""
                if (calcProcess.expression !== panel.query.trim() || !result || result === calcProcess.expression) return
                panel.calcFor = calcProcess.expression
                panel.calcResult = result
                if (panel.copyCalcWhenReady) panel.copyCalc(result)
            }
        }
    }
    property int selected: 0
    readonly property var rows: filtered()
    onIsOpenChanged: {
        if (isOpen && route === "notifications") enterNotifications()
        if (isOpen && route === "passwords") loadPasswords()
        if (!org || !clipboard) return
        if (isOpen) {
            org.error = ""; org.message = ""; openRefresh.restart()
            query = ""; selected = 0; helpVisible = false
            // Search pages (opened by IPC/shortcut, e.g. Super+P) take typing right away.
            Qt.callLater(searchRoutes.indexOf(route) >= 0 ? focusSearch : keyFocus); Qt.callLater(function() { results.positionViewAtBeginning() })
        } else {
            morph = null; morphItem = null; morphAction = null; contextItem = null
            route = "main"; pending = null; clipboard.requestPreview(""); org.tmux.preview(null)
        }
    }
    Component.onCompleted: { if (isOpen) { org.refresh(); keyFocus() } }
    // Unread dots compare against seenAt from before this visit; the visit itself marks all seen.
    property double notificationsSeenBefore: 0
    function enterNotifications() { notificationsSeenBefore = notifications.seenAt; notifications.markSeen() }
    function ago(t) {
        var m = Math.round((Date.now() - t) / 60000)
        return m < 1 ? "now" : m < 60 ? m + " min" : m < 1440 ? Math.round(m / 60) + " h" : Math.round(m / 1440) + " d"
    }
    function notificationRows() {
        var entries = notifications.historyEntries
        // Group by app: apps ordered by their newest entry, newest first inside each app.
        var latest = {}
        entries.forEach(function(e) { latest[e.app] = Math.max(latest[e.app] || 0, e.time) })
        return entries.slice().sort(function(a, b) { return (latest[b.app] - latest[a.app]) || (b.time - a.time) }).map(function(e) {
            var fresh = e.time > notificationsSeenBefore
            return {
                title: (fresh ? "● " : "") + (e.title || "(no title)"),
                subtitle: ago(e.time) + (e.body ? " · " + e.body.replace(/\s+/g, " ") : ""),
                keywords: (e.app || "") + " " + (e.body || ""),
                icon: e.icon || "preferences-system-notifications-symbolic",
                historyKey: e.key, historyApp: e.app || "Notification", historyText: (e.title || "") + (e.body ? "\n" + e.body : "")
            }
        })
    }
    onRouteChanged: {
        if (lastRoute === "main" && route !== "main") mainState = {query: query, selected: selected}
        lastRoute = route
        Qt.callLater(updatePreview)
        if (route === "notifications" && isOpen) enterNotifications()
        if (route === "passwords" && isOpen) loadPasswords()
        contextItem = null
        if (org) org.search((route === "main" || route === "notes") ? query : "")
        if (route === "tmux" && isOpen) org.tmux.refresh()
        if (route === "clipboard" && isOpen) clipboard.refresh()
        helpVisible = false
        Qt.callLater(searchRoutes.indexOf(route) >= 0 ? focusSearch : keyFocus)
    }
    Timer { id: openRefresh; interval: 180; repeat: false; onTriggered: { if (!panel.isOpen) return; org.refresh(); if (panel.route === "clipboard") clipboard.refresh() } }
    Binding { when: !!panel.org; target: panel.org ? panel.org.tmux : null; property: "live"; value: panel.isOpen && (panel.dashboardVisible || panel.route === "tmux") }
    Connections {
        target: panel.clipboard
        function onCopied() { if (panel.route === "clipboard") panel.closeRequested() }
    }
    Connections {
        target: panel.feed
        function onOpenTmux(item) { panel.openTmuxItem(item) }
        function onNavigate(destination) { panel.navigate(destination) }
    }
    function updatePreview() {
        var item = rows[selected]
        if (org) org.tmux.preview(isOpen && route === "tmux" && item ? item : null)
        if (clipboard) clipboard.requestPreview(isOpen && route === "clipboard" && item ? item.clipboardId || "" : "")
    }
    onSelectedChanged: updatePreview()
    onRowsChanged: updatePreview()
    function openControls(column) {
        controlsColumn = column
        route = "controls"; query = ""
    }
    function navigate(destination) {
        if (destination === "controls") { openControls(0); return }
        if (destination === "audio") controlsColumn = 0
        else if (destination === "bluetooth") controlsColumn = 1
        else if (destination === "network") controlsColumn = 2
        route = destination; query = ""; selected = 0
    }
    // Gambito-style focus: the dock opens in key mode; / or i moves to search. Search-centric pages focus search on entry.
    readonly property var searchRoutes: ["notes", "applications", "clipboard", "passwords"]
    property bool helpVisible: false
    property int controlsColumn: 0
    function focusSearch() { search.forceActiveFocus() }
    function keyFocus() {
        if (!isOpen) return
        if (dashboardVisible) { if (dashboardLoader.item) dashboardLoader.item.forceActiveFocus() }
        else if (route === "controls" || route === "audio" || route === "bluetooth" || route === "network") { if (controlsLoader.item) controlsLoader.item.forceActiveFocus() }
        else if (route === "calendar") { if (calendarLoader.item) calendarLoader.item.forceActiveFocus() }
        else if (route === "media") { if (mediaLoader.item) mediaLoader.item.forceActiveFocus() }
        else if (route === "boards") { if (boardsLoader.item) boardsLoader.item.forceActiveFocus() }
        else if (route === "preferences") { if (preferencesLoader.item) preferencesLoader.item.forceActiveFocus() }
        else if (route === "themes") { if (themesLoader.item) themesLoader.item.forceActiveFocus() }
        else if (route === "capture") return
        else listKeys.forceActiveFocus()
    }
    function helpRows() {
        var all = [
            ["/  i", "Search"], ["?", "These keys"], ["Backspace", "Back one level"],
            ["Esc", "Cancel / back"], ["q", "Close the dock"],
            ["notes: clip: tmux:", "Search one source (also apps: notif:)"]
        ]
        if (dashboardVisible) {
            var dashboard = [
                ["n", "Capture task"], ["d", "Today's note"], ["s", "Dock preferences"],
                ["o", "Notes"], ["t", "Agents · tmux"], ["C", "Calendar"], ["c", "Audio"],
                ["B", "Bluetooth"], ["w", "Network"], ["v", "Clipboard"],
                ["a", "Applications"], ["P", "Power"]
            ]
            return all.concat(dashboard).concat(feed.cards.map(function(c) { return [c.key, c.title] }))
        }
        if (route === "calendar") return all.concat([["hjkl ←↓↑→", "Day / week"], ["[  ]", "Month"], ["g", "Today"], ["J  K", "Select event"]])
        if (route === "media") return all.concat([
            ["Space", "Play / pause"], ["←  →", "Previous / next"], ["s", "Shuffle"],
            ["u", "Queue"], ["r", "Recently played"], ["Click", "Seek"], ["Esc", "Back"]
        ])
        if (route === "boards") return all.concat([
            ["j  k  ↓↑", "Select demand"], ["Enter  o", "Details / open in Azure"],
            ["r", "Refresh"], ["Esc", "Back"]
        ])
        if (route === "preferences") return all.concat([["j  k  ↓↑", "Select"], ["Enter  Space", "Toggle"], ["Esc", "Back"]])
        if (["controls", "audio", "bluetooth", "network"].indexOf(route) >= 0) return all.concat([
            ["j  k", "Item"], ["Enter  Space", "Toggle / select"], ["-  +", "Volume"],
            ["m", "Mute"], ["a", "Advanced (TUI)"]
        ])
        return all.concat([["j  k  ↓↑", "Select"], ["g  G", "First / last"], ["Enter  e", route === "tmux" ? "Resume in Super + C" : "Open"], ["Ctrl+K", "Context actions"]])
    }
    // Resume a tmux window by turning the dock into the Super + C scratchpad: the dock's
    // rect moves onto the window's exact geometry (scratchpad-center: 80% × 79%, centered),
    // then the window is shown underneath without Hyprland's slide and the dock fades out.
    property var morph: null
    property var morphItem: null
    property var morphAction: null
    // Set while jumping straight to a rect (scratchpad -> dock starts at the window, not animated there).
    property bool morphInstant: false
    property bool transitionOnly: false
    // Dock -> rect: animate onto it, then run `action` (show the window underneath).
    function morphInto(rect, action) {
        if (morph) return
        morphAction = action
        morph = rect
        morphTimer.restart()
    }
    // Rect -> dock: appear exactly over the scratchpad's window; morphRelease() animates back.
    // Stays instant until the release: the closed window is 0×0, so the centering offsets jump
    // when it maps and must not animate (that slid the dock in from the bottom-right corner).
    function morphFrom(rect) {
        morphInstant = true
        morph = rect
    }
    function morphRelease() { morphInstant = false; morph = null; morphItem = null }
    function morphToTmux(item) {
        if (org.tmux.busy || morph) return
        var top = showTopBar ? 40 : 0, w = Math.floor(width * 0.8), h = Math.floor(height * 0.79)
        morphItem = item
        if (!panel.buttonPreferences.tmuxMorph) { panel.org.tmux.open(item, false); panel.closeRequested(); return }
        morphInto({x: Math.round((width - w) / 2), y: Math.round(top + (height - top - h) / 2), w: w, h: h}, function() { panel.org.tmux.open(item, true) })
    }
    Timer { id: morphTimer; interval: 230; onTriggered: { if (panel.morphAction) panel.morphAction() } }
    // Back returns to where you were: the row a Ctrl+K menu was opened from, and the main
    // search (query + selection) a page was opened from. Prefix queries ("notes: x") aren't
    // restored, since they would jump straight back to that page.
    property int contextFrom: 0
    onContextItemChanged: { if (contextItem) contextFrom = selected; else { passFieldsFor = ""; passFieldNames = [] } }
    property string lastRoute: "main"
    property var mainState: ({query: "", selected: 0})
    function goBack() {
        if (contextItem) { var from = contextFrom; contextItem = null; selected = from; return }
        pending = null
        var saved = mainState
        route = "main"
        var prefixed = /^(notes|clip|tmux|apps|notif|pass):/i.test(saved.query)
        query = prefixed ? "" : saved.query
        selected = prefixed ? 0 : saved.selected
        mainState = {query: "", selected: 0}
        Qt.callLater(saved.query && !prefixed ? focusSearch : keyFocus)
    }
    readonly property var applicationCatalog: applicationRows()
    function applicationRows() {
        return DesktopEntries.applications.values.map(function(entry) {
            var keywords = [entry.genericName, entry.comment, entry.id].concat(Array.from(entry.keywords)).join(" ")
            return {
                searchText: (entry.name + " " + keywords).toLowerCase(),
                title: entry.name,
                subtitle: entry.genericName || entry.comment || entry.id,
                keywords: keywords,
                icon: entry.icon,
                desktopId: entry.id
            }
        }).sort(function(a, b) { return a.title.localeCompare(b.title) })
    }
    function activate(index) {
        // Enter typed faster than qalc answers: copy the result once it arrives.
        if (route === "main" && looksLikeMath(query) && !(rows[0] && rows[0].calcValue !== undefined) && (calcProcess.running || calcDebounce.running)) { copyCalcWhenReady = true; return }
        var item = rows[index]
        if (!item) return
        if (item.tmuxWindow) { morphToTmux(item); return }
        if (item.tmuxAction) {
            var tmuxItem = contextItem
            if (item.tmuxAction === "resume") { contextItem = null; morphToTmux(tmuxItem); return }
            if (item.tmuxAction === "directory" && tmuxItem.panePath) {
                Quickshell.execDetached({command: ["ghostty", "-e", "yazi", tmuxItem.panePath]})
                panel.closeRequested(); return
            }
            if (item.tmuxAction === "filter") { contextItem = null; route = "tmux"; query = tmuxItem.sessionName; selected = 0; return }
        }
        if (item.noteAction) {
            var note = contextItem
            if (item.noteAction === "pin") org.togglePin(note)
            else org.run(item.noteAction, [note.orgPath, String(note.orgLine)])
            contextItem = null; selected = 0
            return
        }
        if (item.calcValue !== undefined) { copyCalc(item.calcValue); return }
        if (item.passPending) return
        if (item.passEntry) { openPassFields(item.passEntry); return }
        if (item.passAction) {
            var passItem = contextItem
            contextItem = null; selected = 0
            if (item.passAction === "edit") { Quickshell.execDetached(["ghostty", "-e", "pass", "edit", passItem.passEntry]); panel.closeRequested() }
            else copyPass(passItem.passEntry, item.passAction)
            return
        }
        if (item.ruleApp) { notifications.setRule(item.ruleApp, ""); return }
        if (item.historyKey) {
            // Live notification with a default action: run it. Otherwise copy its text.
            if (!notifications.invokeDefault(notifications.liveFor(item.historyKey))) Quickshell.execDetached(["wl-copy", item.historyText])
            panel.closeRequested(); return
        }
        if (item.historyAction) {
            var entry = contextItem
            contextItem = null; selected = 0
            if (item.historyAction === "copy") { Quickshell.execDetached(["wl-copy", entry.historyText]); panel.closeRequested() }
            else if (item.historyAction === "open") { notifications.invokeDefault(notifications.liveFor(entry.historyKey)); panel.closeRequested() }
            else if (item.historyAction === "remove") notifications.removeEntry(entry.historyKey)
            else if (item.historyAction === "clearApp") notifications.clearApp(entry.historyApp)
            else if (item.historyAction.indexOf("rule:") === 0) notifications.setRule(entry.historyApp, item.historyAction.slice(5))
            return
        }
        if (item.orgPath) { org.run("open", [item.orgPath, String(item.orgLine)]); return }
        if (item.orgAction) { org.run(item.orgAction); return }
        if (item.toggleTopBar) { panel.toggleTopBarRequested(); return }
        if (item.meetingAction !== undefined) { if (item.meetingAction) meeting.start(item.meetingAction); else meeting.stop(); panel.closeRequested(); return }
        if (item.clipboardId) { clipboard.copyEntry(item.clipboardId); return }
        if (item.desktopId) {
            var entry = DesktopEntries.byId(item.desktopId)
            if (!entry) return
            var command = Array.from(entry.command)
            if (!command.length) return
            if (entry.runInTerminal) command = ["ghostty", "-e"].concat(command)
            Quickshell.execDetached({command: command, workingDirectory: entry.workingDirectory})
            panel.closeRequested()
            return
        }
        if (item.notificationAction) {
            if (item.notificationAction === "dnd") notifications.toggleDnd()
            if (item.notificationAction === "dnd60") notifications.snoozeDnd(60)
            if (item.notificationAction === "clear") notifications.clearHistory()
            if (item.notificationAction === "history") { navigate("notifications"); return }
            return
        }
        if (item.cancel) { pending = null; return }
        if (item.controlsColumn !== undefined) { openControls(item.controlsColumn); return }
        if (item.notesQuery !== undefined) { var q = item.notesQuery; route = "notes"; query = q; selected = 0; return }
        if (item.route) {
            route = item.route
            if (route === "audio") controlsColumn = 0
            else if (route === "bluetooth") controlsColumn = 1
            else if (route === "network") controlsColumn = 2
            query = ""; selected = 0; return
        }
        if (item.confirm) { pending = item; query = ""; selected = 0; return }
        Quickshell.execDetached(["bash", "-lc", item.command])
        panel.closeRequested()
    }

    function filtered() {
        var q = query.toLowerCase().trim()
        if (contextItem) {
            if (contextItem.passEntry && passFieldsFor === contextItem.passEntry) return passFieldNames.map(function(name) {
                return {title: passFieldTitle(name), subtitle: "Value stays hidden · clears from the clipboard after 45 s", passAction: name}
            }).concat([{title: "Edit in terminal", subtitle: "pass edit " + contextItem.passEntry, passAction: "edit"}])
            if (contextItem.passEntry) return [{title: "Decrypting…", subtitle: "Your GPG passphrase may be asked", passPending: true}]
            if (contextItem.historyKey) return (notifications.liveFor(contextItem.historyKey) ? [{title: "Open", subtitle: "Run the notification's default action", historyAction: "open"}] : []).concat([
                {title: "Copy text", subtitle: "Title and body to the clipboard", historyAction: "copy"},
                {title: "Dismiss", subtitle: "Remove from history", historyAction: "remove"},
                {title: "Clear all from " + contextItem.historyApp, subtitle: "Remove every entry from this app", historyAction: "clearApp"}
            ]).concat(notifications.ruleFor(contextItem.historyApp) === "mute"
                ? [{title: "Unmute " + contextItem.historyApp, subtitle: "Show its popups again", historyAction: "rule:"}]
                : [{title: "Mute " + contextItem.historyApp, subtitle: "Keep in history, no popups (critical ones still show)", historyAction: "rule:mute"}]
            ).concat(notifications.ruleFor(contextItem.historyApp) === "always"
                ? [{title: "Stop always showing " + contextItem.historyApp, subtitle: "Follow Do not disturb again", historyAction: "rule:"}]
                : [{title: "Always show " + contextItem.historyApp, subtitle: "Pop up even during Do not disturb", historyAction: "rule:always"}])
            if (contextItem.tmuxWindow) return [
                {title: "Resume in Super + C", tmuxAction: "resume"},
                {title: "Open session directory", tmuxAction: "directory"},
                {title: "Filter this session", tmuxAction: "filter"}
            ]
            return [
                {title: "Open in Emacs", noteAction: "open"},
                {title: "Copy Org link", noteAction: "link"},
                {title: org.pinned(contextItem) ? "Unpin note" : "Pin note", noteAction: "pin"}
            ]
        }
        if (dashboardVisible) return homeRows()
        if (route === "capture") return []
        if (route === "notes") return q ? org.entries : org.pins.concat(org.home.recent)
        if (pending) return [{title: "Cancel", cancel: true}, {title: "Confirm " + pending.title, command: pending.command}]
        var source = route === "power" ? Actions.power() : Actions.all()
        if (route === "tmux") source = org.tmux.entries
        if ((route === "main" || route === "actions") && meeting) source = source.concat(meeting.active ? [{
            title: "Meeting mode: on until " + Qt.formatTime(new Date(meeting.until), "HH:mm"), subtitle: "Enter ends it now",
            keywords: "meeting call focus dnd stop end", icon: "camera-web", meetingAction: 0
        }] : [30, 60].map(function(minutes) { return {
            title: "Meeting mode · " + minutes + " min", subtitle: "Do not disturb and no sleep, then back to normal",
            keywords: "meeting call focus dnd sleep inhibit", icon: "camera-web", meetingAction: minutes
        } }))
        if (route === "main" || route === "actions") source = source.concat([{
            title: "Show top bar: " + (panel.showTopBar ? "On" : "Off"),
            keywords: "topbar bar dock painel desktop toggle",
            icon: "preferences-desktop-display",
            toggleTopBar: true
        }])
        var notificationActions = [
            {
                title: "Do not disturb: " + (notifications.dnd ? "On" + (notifications.dndUntil > 0 ? " until " + Qt.formatTime(new Date(notifications.dndUntil), "HH:mm") : "") : "Off"),
                subtitle: "Suppress non-critical popups", keywords: "Toggle notification popups", notificationAction: "dnd"
            },
            {
                title: "Do not disturb for 1 hour", subtitle: "Turns itself off at " + Qt.formatTime(new Date(Date.now() + 3600000), "HH:mm"),
                keywords: "Snooze notification popups dnd timer meeting focus", notificationAction: "dnd60"
            },
            {
                title: "Notification center", subtitle: notifications.historyEntries.length + " saved" + (notifications.unread ? " · " + notifications.unread + " unread" : ""),
                keywords: "Recent notifications history inbox", notificationAction: "history"
            },
            {
                title: "Clear notification history", subtitle: "Remove saved notification entries",
                keywords: "Forget recent notification entries", notificationAction: "clear"
            }
        ]
        if (route === "notifications") source = notificationRows().concat(notificationActions.filter(function(a) { return a.notificationAction !== "history" }))
            .concat(Object.keys(notifications.appRules).map(function(app) {
                var muted = notifications.appRules[app] === "mute"
                return {title: (muted ? "Muted: " : "Always shown: ") + app, subtitle: "Enter removes this rule", keywords: "rule mute always " + app,
                        icon: "preferences-system-notifications-symbolic", ruleApp: app}
            }))
        else if (q && route === "main") source = source.concat(notificationActions)
        if (route === "clipboard") source = clipboard.entries
        if (route === "passwords") source = passEntries.map(function(e) {
            return {title: e.leaf, subtitle: e.folder || "password-store", keywords: e.name, icon: "dialog-password", passEntry: e.name}
        })
        if (route === "applications") source = applicationCatalog
        else if (q && route === "main") {
            // Keep established actions (e.g. the scratch editor) ahead of same-name apps.
            var actionNames = source.map(function(item) { return item.title.toLowerCase() })
            source = source.concat(applicationCatalog.filter(function(item) {
                return actionNames.indexOf(item.title.toLowerCase()) < 0
            }))
        }
        if (!q) return source
        var terms = q.split(/\s+/)
        function rank(item) {
            var title = item.title.toLowerCase()
            return title === q ? 0 : title.indexOf(q) === 0 ? 1 : title.indexOf(q) >= 0 ? 2 : 3
        }
        var matches = source.filter(function(item) {
            var text = item.searchText || (item.title + " " + (item.keywords || "")).toLowerCase()
            return terms.every(function(term) { return text.indexOf(term) >= 0 })
        }).sort(function(a, b) { return panel.route === "clipboard" ? 0 : rank(a) - rank(b) || a.title.localeCompare(b.title) })
        if (route !== "main") return matches
        // Apps and actions stay on top; notes arrive async and must not push them down.
        var agents = org.tmux.entries.filter(function(item) {
            var text = (item.title + " " + item.keywords).toLowerCase()
            return terms.every(function(term) { return text.indexOf(term) >= 0 })
        })
        var notes = org.entries.slice(0, 5)
        if (org.entries.length) notes.push({title: "Search all notes for “" + query.trim() + "”", subtitle: "Notes page · o", icon: "edit-find", notesQuery: query.trim()})
        var calc = calcResult && calcFor === query.trim() ? [{title: calcResult, subtitle: "= " + calcFor + " · Enter copies", icon: "accessories-calculator", calcValue: calcResult}] : []
        return calc.concat(matches).concat(agents).concat(notes)
    }

    Connections {
        target: panel.feed
        function onNavigate(destination) { panel.navigate(destination) }
        function onOpenTmux(item) { panel.openTmuxItem(item) }
        function onCloseRequested() { panel.closeRequested() }
    }
    Connections {
        target: panel.org.tmux
        function onOpened() { panel.closeRequested() }
        function onErrorChanged() { if (panel.org.tmux.error) panel.morph = null }
    }
    Connections {
        target: panel.org
        function onOpened() { panel.closeRequested() }
        function onCaptured() { panel.captureText = ""; panel.goBack() }
    }

    visible: panel.isOpen
    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: -1
    color: "#52000000"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "yerba-menu"
    WlrLayershell.keyboardFocus: panel.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None


    MouseArea {
        anchors.fill: parent
        onClicked: panel.closeRequested()
    }

    StatusStrip {
        visible: !panel.showTopBar && !panel.transitionOnly
        theme: panel.theme
        time: panel.time
        dnd: panel.notifications.dnd
        meeting: !!panel.meeting && panel.meeting.active
        unread: panel.notifications.unread
        onControlsRequested: function(column) { panel.openControls(column) }
        opacity: panel.morph ? 0 : 1
        Behavior on opacity { enabled: !panel.morphInstant; NumberAnimation { duration: 120 } }
        anchors.bottom: dock.top
        anchors.bottomMargin: 8
        anchors.horizontalCenter: dock.horizontalCenter
        width: dock.width
        height: 34
    }

    Rectangle {
        id: dock
        Behavior on width { enabled: !panel.morphInstant; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on height { enabled: !panel.morphInstant; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on anchors.horizontalCenterOffset { enabled: !panel.morphInstant; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on anchors.verticalCenterOffset { enabled: !panel.morphInstant; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        width: panel.morph ? panel.morph.w : Math.min((panel.dashboardVisible || panel.fullView) ? 1060 : panel.route === "clipboard" ? 1040 : 740, parent.width - 32)
        height: panel.morph ? panel.morph.h : panel.dockHeight(parent.height)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        // Centraliza o conjunto faixa de status + dock, não só o dock.
        // Nos dois modos existe conteúdo reservado acima da dock: a top bar
        // global ou a faixa de status interna. Centralize o conjunto abaixo.
        anchors.verticalCenterOffset: panel.morph ? panel.morph.y + panel.morph.h / 2 - parent.height / 2 : 21
        anchors.horizontalCenterOffset: panel.morph ? panel.morph.x + panel.morph.w / 2 - parent.width / 2 : 0
        radius: 7
        color: theme.background
        border.color: theme.border
        border.width: 1
        clip: true

        MouseArea { anchors.fill: parent }
        Rectangle {
            visible: panel.transitionOnly
            anchors.fill: parent
            z: 100
            radius: dock.radius
            color: theme.background
            border.color: theme.border
            border.width: dock.border.width
        }
        // Morph cover: fade the dock content out while the scratchpad takes its rect.
        Rectangle {
            anchors.fill: parent; z: 20; radius: dock.radius
            color: theme.background
            opacity: panel.morph ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { enabled: !panel.morphInstant; NumberAnimation { duration: 140 } }
        }
        Item {
            id: header
            height: 54
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            Text {
                id: prefix
                MouseArea { anchors.fill: parent; enabled: panel.route !== "main" || panel.contextItem !== null; onClicked: panel.goBack() }
                text: panel.route === "main" && !panel.contextItem ? "⌕" : "‹ Back"
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                color: theme.foreground
                font.pixelSize: 14
            }
            TextInput {
                id: search
                anchors.left: prefix.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 74
                anchors.verticalCenter: parent.verticalCenter
                color: theme.foreground
                font.pixelSize: 15
                clip: true
                text: panel.query
                onTextChanged: { panel.query = text; panel.selected = 0 }
                Text {
                    visible: !search.text
                    text: panel.searchPlaceholder()
                    color: theme.foreground
                    opacity: 0.6
                    font.pixelSize: 15
                }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
                        var item = panel.rows[panel.selected]
                        if (item && (item.orgPath || item.historyKey)) { panel.contextItem = item; panel.selected = 0 }
                        event.accepted = true
                    }
                    if (event.key === Qt.Key_Left && (event.modifiers & Qt.AltModifier)) {
                        panel.goBack()
                        event.accepted = true
                    }
                }
                // In a context list (password fields, note actions) Esc goes straight back to the list.
                Keys.onEscapePressed: { if (panel.contextItem) { panel.goBack(); return } if (panel.query) panel.query = ""; panel.keyFocus() }
                Keys.onDownPressed: panel.selected = Math.min(panel.rows.length - 1, panel.selected + 1)
                Keys.onUpPressed: panel.selected = Math.max(0, panel.selected - 1)
                Keys.onReturnPressed: panel.activate(panel.selected)
                Keys.onEnterPressed: panel.activate(panel.selected)
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: "Esc"
                color: theme.foreground
                opacity: 0.6
                font.family: "monospace"
                font.pixelSize: 11
            }
        }
        Rectangle {
            anchors.top: header.bottom
            width: parent.width
            height: 1
            color: theme.border
            opacity: 0.5
        }
        Item {
            id: section
            visible: !panel.dashboardVisible && panel.route !== "capture" && !panel.fullView
            anchors.top: header.bottom
            width: parent.width
            height: 30
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: panel.sectionTitle()
                color: theme.foreground
                opacity: 0.6
                font.pixelSize: 12
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: panel.rows.length + (panel.route === "applications" ? (panel.rows.length === 1 ? " app" : " apps") : (panel.rows.length === 1 ? " result" : " results"))
                color: theme.foreground
                opacity: 0.6
                font.pixelSize: 12
            }
        }
        ListView {
            id: results
            visible: !panel.dashboardVisible && panel.route !== "capture" && !panel.fullView
            anchors.top: section.bottom
            anchors.bottom: footer.top
            anchors.left: parent.left
            anchors.right: panel.route === "clipboard" ? previewPane.left : parent.right
            anchors.margins: 8
            clip: true
            model: panel.rows
            currentIndex: panel.selected
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: Rectangle {
                required property int index
                required property var modelData
                width: results.width
                height: 48
                radius: 4
                color: index === panel.selected ? Qt.alpha(theme.accent, 0.13) : "transparent"
                Text {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.orgPath ? "·" : ""
                    color: theme.foreground
                    opacity: 0.55
                    font.family: "monospace"
                    font.pixelSize: 11
                }
                Item {
                    x: 36
                    width: 24; height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    Image {
                        id: entryIcon
                        anchors.fill: parent
                        readonly property string iconName: modelData.icon || (modelData.notificationAction ? "preferences-system-notifications-symbolic" : "")
                        source: !iconName ? "" : iconName.startsWith("/") ? "file://" + iconName : (Quickshell.iconPath(iconName, true) || Quickshell.iconPath("application-x-executable", true))
                        sourceSize.width: 24; sourceSize.height: 24
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !entryIcon.visible
                        text: modelData.title.charAt(0).toUpperCase()
                        color: theme.foreground
                        font.pixelSize: 16
                    }
                }
                Column {
                    x: 70
                    width: parent.width - 150
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text { width: parent.width; text: modelData.title; textFormat: Text.PlainText; elide: Text.ElideRight; color: theme.foreground; font.pixelSize: 14 }
                    Text {
                        width: parent.width
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        text: modelData.subtitle || modelData.keywords || (modelData.cancel ? "Return without changes" : "Session action")
                        color: theme.foreground
                        opacity: 0.6
                        font.family: "monospace"
                        font.pixelSize: 11
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.itemKind(modelData)
                    font.pixelSize: 11
                    color: theme.foreground
                    opacity: 0.6
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: panel.activate(index)
                }
            }
            Text {
                anchors.centerIn: parent
                visible: panel.rows.length === 0
                text: panel.emptyMessage()
                color: theme.foreground
                opacity: 0.6
            }
        }
        // Pages are created only while on screen and destroyed on leave (Gambito's Loader pattern), so hidden views cost no RAM or bindings.
        Loader {
            id: tmuxLoader
            anchors.top: header.bottom; anchors.bottom: footer.top
            anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 18
            active: panel.isOpen && panel.route === "tmux"
            sourceComponent: Component {
                TmuxView {
                    theme: panel.theme; store: panel.org.tmux; rows: panel.rows; selected: panel.selected
                    showButtons: panel.buttonPreferences.showButtons
                    opacity: 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Component.onCompleted: opacity = 1
                    onSelect: function(index) { panel.selected = index }
                    onActivate: function(index) { panel.activate(index) }
                }
            }
        }
        Loader {
            id: controlsLoader
            anchors.top: header.bottom; anchors.bottom: footer.top
            anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 18
            active: panel.isOpen && ["controls", "audio", "bluetooth", "network"].indexOf(panel.route) >= 0
            onLoaded: { if (!search.activeFocus) panel.keyFocus() }
            sourceComponent: Component {
                ControlsView {
                    theme: panel.theme
                    active: true
                    column: panel.controlsColumn
                    opacity: 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Component.onCompleted: opacity = 1
                    onBack: panel.goBack()
                    onHelpRequested: panel.helpVisible = true
                    onCloseRequested: panel.closeRequested()
                }
            }
        }
        Loader {
            id: calendarLoader
            anchors.top: header.bottom; anchors.bottom: footer.top
            anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 18
            active: panel.isOpen && panel.route === "calendar"
            onLoaded: { if (!search.activeFocus) panel.keyFocus() }
            sourceComponent: Component {
                CalendarView {
                    theme: panel.theme; org: panel.org
                    opacity: 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Component.onCompleted: opacity = 1
                    onBack: panel.goBack()
                    onHelpRequested: panel.helpVisible = true
                    onCloseRequested: panel.closeRequested()
                }
            }
        }
        Loader {
            id: mediaLoader
            anchors.top: header.bottom; anchors.bottom: footer.top
            anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 18
            active: panel.isOpen && panel.route === "media"
            onLoaded: {
                if (mediaLoader.item) mediaLoader.item.forceActiveFocus()
                if (!search.activeFocus) panel.keyFocus()
            }
            sourceComponent: Component {
                MediaView {
                    theme: panel.theme
                    media: panel.media
                    buttonPreferences: panel.buttonPreferences
                    opacity: 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Component.onCompleted: opacity = 1
                    onBack: panel.goBack()
                    onCloseRequested: panel.closeRequested()
                    onHelpRequested: panel.helpVisible = true
                }
            }
        }
        Loader {
            id: boardsLoader
            anchors.top: header.bottom; anchors.bottom: footer.top
            anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 18
            active: panel.isOpen && panel.route === "boards"
            onLoaded: { if (!search.activeFocus) panel.keyFocus() }
            sourceComponent: Component {
                BoardsView {
                    theme: panel.theme
                    store: panel.feed.azure
                    buttonPreferences: panel.buttonPreferences
                    opacity: 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Component.onCompleted: opacity = 1
                    onBack: panel.goBack()
                    onCloseRequested: panel.closeRequested()
                    onHelpRequested: panel.helpVisible = true
                }
            }
        }
        Loader {
            id: dashboardLoader
            anchors.top: header.bottom; anchors.topMargin: 8
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 18; anchors.rightMargin: 18
            anchors.bottom: footer.top; anchors.bottomMargin: 8
            active: panel.isOpen && panel.dashboardVisible
            onLoaded: { if (!search.activeFocus) panel.keyFocus() }
            sourceComponent: Component {
                Dashboard {
                    feed: panel.feed
                    buttonPreferences: panel.buttonPreferences
                    opacity: 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    Component.onCompleted: opacity = 1
                    theme: panel.theme
                    org: panel.org
                    onSearchRequested: panel.focusSearch()
                    onCloseRequested: panel.closeRequested()
                    onHelpRequested: panel.helpVisible = true
                    onNavigate: function(destination) { panel.navigate(destination) }
                    onOpenTmux: function(item) { panel.openTmuxItem(item) }
                }
            }
        }
        Loader {
            id: preferencesLoader
            anchors.top: header.bottom; anchors.bottom: footer.top
            anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 18
            active: panel.isOpen && panel.route === "preferences"
            onLoaded: { if (!search.activeFocus) panel.keyFocus() }
            sourceComponent: Component {
                PreferencesView {
                    theme: panel.theme
                    preferences: panel.buttonPreferences
                    opacity: 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Component.onCompleted: opacity = 1
                    onBack: panel.goBack()
                    onThemesRequested: { panel.route = "themes"; panel.query = ""; panel.selected = 0; Qt.callLater(panel.keyFocus) }
                    onHelpRequested: panel.helpVisible = true
                    onCloseRequested: panel.closeRequested()
                }
            }
        }
        Loader {
            id: themesLoader
            anchors.top: header.bottom; anchors.bottom: footer.top
            anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 18
            active: panel.isOpen && panel.route === "themes"
            onLoaded: { if (!search.activeFocus) panel.keyFocus() }
            sourceComponent: Component {
                ThemeView {
                    theme: panel.theme
                    opacity: 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Component.onCompleted: opacity = 1
                    onBack: panel.goBack()
                    onCloseRequested: panel.closeRequested()
                }
            }
        }
        Column {
            visible: panel.route === "capture"
            x: 20; y: header.height + 22
            width: parent.width - 40
            spacing: 16
            Text { text: "Capture task"; font.pixelSize: 20; color: theme.foreground }
            Text { text: "Target: Tasks: #personal · today's note"; font.pixelSize: 12; color: theme.foreground; opacity: 0.65 }
            Rectangle {
                width: parent.width; height: 42; radius: 5
                color: Qt.alpha(theme.foreground, 0.04); border.color: theme.border
                TextInput {
                    id: captureInput
                    anchors.fill: parent; anchors.margins: 12
                    color: theme.foreground; font.pixelSize: 14; clip: true
                    maximumLength: 2000
                    text: panel.captureText
                    onTextChanged: panel.captureText = text
                    Text { visible: !captureInput.text; text: "What do you need to do?"; color: theme.foreground; opacity: 0.5 }
                    Keys.onEscapePressed: panel.goBack()
                    Keys.onReturnPressed: { if (text.trim()) panel.org.run("capture", [text]) }
                    Keys.onEnterPressed: { if (text.trim()) panel.org.run("capture", [text]) }
                }
            }
            Text {
                text: panel.org.busy ? "Saving…" : "Add task  ↵"
                color: theme.accent; font.pixelSize: 14
                MouseArea { anchors.fill: parent; enabled: !!panel.captureText.trim() && !panel.org.busy; onClicked: panel.org.run("capture", [panel.captureText]) }
            }
            onVisibleChanged: { if (visible) Qt.callLater(function() { captureInput.forceActiveFocus() }) }
        }
        Item {
            id: previewPane
            visible: panel.route === "clipboard"
            anchors.top: section.bottom
            anchors.bottom: footer.top
            anchors.right: parent.right
            width: parent.width * 0.43
            Rectangle { width: 1; height: parent.height; color: theme.border; opacity: 0.45 }
            Text {
                x: 16; y: 8
                text: panel.clipboard.previewLoading ? "Loading preview…" : "Preview"
                font.pixelSize: 12; color: theme.foreground; opacity: 0.65
            }
            Image {
                anchors.fill: parent
                anchors.margins: 16
                anchors.topMargin: 36
                source: panel.clipboard.previewImage
                cache: false
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                visible: source.toString().length > 0
                sourceSize.width: Math.max(1, width * 2)
                sourceSize.height: Math.max(1, height * 2)
            }
            Flickable {
                id: textPreview
                anchors.fill: parent
                anchors.margins: 16
                anchors.topMargin: 36
                clip: true
                visible: !panel.clipboard.previewImage
                contentWidth: width
                contentHeight: previewBody.height
                boundsBehavior: Flickable.StopAtBounds
                Text {
                    id: previewBody
                    width: textPreview.width
                    text: panel.clipboard.previewText
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: theme.foreground
                    onTextChanged: textPreview.contentY = 0
                }
            }
        }
        // Key mode for list pages (actions, power, notes results, tmux…): j/k, Enter, Backspace back.
        Item {
            id: listKeys
            Keys.onPressed: function(event) {
                var k = event.text, last = Math.max(0, panel.rows.length - 1)
                if (k === "/" || k === "i") panel.focusSearch()
                else if (k === "?") panel.helpVisible = true
                else if (panel.route === "tmux" && k === "e") panel.activate(panel.selected)
                else if (k === "q") panel.closeRequested()
                else if (k === "j" || event.key === Qt.Key_Down) panel.selected = Math.min(last, panel.selected + 1)
                else if (k === "k" || event.key === Qt.Key_Up) panel.selected = Math.max(0, panel.selected - 1)
                else if (k === "g") panel.selected = 0
                else if (k === "G") panel.selected = last
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) panel.activate(panel.selected)
                else if (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
                    var item = panel.rows[panel.selected]
                    if (item && (item.orgPath || item.tmuxWindow || item.historyKey)) {
                        panel.contextItem = item
                        panel.selected = 0
                    }
                }
                else if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape) panel.goBack()
                else return
                event.accepted = true
            }
        }
        FocusScope {
            id: help
            anchors.fill: parent
            visible: panel.helpVisible
            z: 10
            onVisibleChanged: { if (visible) forceActiveFocus(); else Qt.callLater(panel.keyFocus) }
            Keys.onPressed: function(event) { panel.helpVisible = false; event.accepted = true }
            MouseArea { anchors.fill: parent; onClicked: panel.helpVisible = false }
            Rectangle { anchors.fill: parent; color: theme.background; opacity: 0.94; radius: 7 }
            Column {
                anchors.centerIn: parent
                spacing: 14
                Text { text: "Keys"; color: theme.foreground; font.pixelSize: 18 }
                Grid {
                    columns: 2; columnSpacing: 48; rowSpacing: 7
                    flow: Grid.TopToBottom
                    rows: Math.ceil(panel.helpRows().length / 2)
                    Repeater {
                        model: panel.helpVisible ? panel.helpRows() : []
                        delegate: Row {
                            required property var modelData
                            spacing: 14
                            Text { width: 110; text: modelData[0]; color: theme.accent; font.family: "monospace"; font.pixelSize: 12; horizontalAlignment: Text.AlignRight }
                            Text { text: modelData[1]; color: theme.foreground; font.pixelSize: 12 }
                        }
                    }
                }
                Text { text: "Any key closes"; color: theme.foreground; opacity: 0.5; font.pixelSize: 11 }
            }
        }
        Item {
            id: footer
            anchors.bottom: parent.bottom
            width: parent.width
            height: 32
            Rectangle { width: parent.width; height: 1; color: theme.border; opacity: 0.5 }
            Text {
                x: 16
                width: parent.width - 100
                elide: Text.ElideRight
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                    text: panel.footerHint()
                font.pixelSize: 11
                color: theme.foreground
                opacity: 0.7
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: panel.route === "clipboard" ? (panel.clipboard.copying ? "Copying…" : panel.clipboard.error ? "Copy failed — retry" : "Clipboard") : "Desktop"
                font.pixelSize: 11
                color: theme.foreground
                opacity: 0.6
            }
        }
    }
}
