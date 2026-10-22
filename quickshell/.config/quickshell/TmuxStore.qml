import QtQuick
import Quickshell
import Quickshell.Io
Scope {
    id: store
    property var entries: []
    property string error: ""
    readonly property bool loading: reader.running || daemonBusy
    readonly property bool busy: opener.running
    readonly property var sessions: {
        var groups = []
        entries.forEach(function(row) {
            var existing = groups.find(function(g) { return g.sessionName === row.sessionName })
            if (!existing) groups.push({sessionName: row.sessionName, count: 1, current: row})
            else { existing.count++; if (row.active) existing.current = row }
        })
        return groups
    }
    property QtObject theme: Theme {}
    // Ligado pelo Menu enquanto dashboard ou view tmux estão visíveis.
    property bool live: false
    property string entriesSnapshot: ""
    readonly property var agents: entries.filter(function(row) { return !!row.agent })
    readonly property int plainTerminals: entries.length - agents.length
    // Fast while visible; a cheap background check keeps "needs you" fresh for the dashboard.
    Timer { interval: store.live ? 1500 : 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: store.refresh() }
    function withStatus(rows) {
        rows.forEach(function(row) {
            if (row.agent) row.status = row.waiting ? "waiting" : row.working ? "working" : "idle"
            // Screen digests are transport details, not visible model data.
            delete row.digest
        })
        return rows
    }
    property var previewItem: null
    property string previewHtml: ""
    property string previewError: ""
    property string previewKey: ""
    property string previewRaw: ""
    property int unchangedPreviews: 0
    readonly property string previewPalette: JSON.stringify([theme.ansi, String(theme.foreground), String(theme.background)])
    onPreviewPaletteChanged: { previewRaw = ""; unchangedPreviews = 0 }
    property int previewCols: 80
    property int previewRows: 24
    function preview(item) {
        var key = item ? item.tmuxSession + ":" + item.tmuxWindow : ""
        if (key === previewKey) return
        previewRaw = ""; unchangedPreviews = 0
        previewKey = key; previewItem = item; previewHtml = ""; previewError = ""
        previewDelay.restart()
    }
    Timer { id: previewDelay; interval: 50; onTriggered: store.loadPreview() }
    Timer { interval: store.unchangedPreviews >= 5 ? 1000 : 300; running: store.previewItem !== null; repeat: true; onTriggered: store.loadPreview() }
    function loadPreview() {
        if (!previewItem || previewer.running) return
        previewer.key = previewKey
        var target = previewItem.tmuxSession + ":" + previewItem.tmuxWindow
        previewer.command = ["tmux", "display-message", "-p", "-t", target, "#{pane_width} #{pane_height}", ";", "capture-pane", "-e", "-p", "-t", target]
        previewer.running = true
    }
    // Converte a saída de capture-pane -e (SGR 16/256/truecolor) em rich text.
    function ansiHtml(text) {
        var palette = theme ? theme.ansi : []
        function hex(n) { return ("0" + Math.max(0, Math.min(255, n)).toString(16)).slice(-2) }
        function indexed(n) {
            if (n < 16) return palette[n] || ""
            if (n < 232) { var v = [0, 95, 135, 175, 215, 255]; n -= 16; return "#" + hex(v[Math.floor(n / 36)]) + hex(v[Math.floor(n / 6) % 6]) + hex(v[n % 6]) }
            var g = 8 + (n - 232) * 10; return "#" + hex(g) + hex(g) + hex(g)
        }
        function escape(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
        var st = {fg: "", bg: "", bold: false, dim: false, italic: false, underline: false, reverse: false}
        function apply(params) {
            var p = params === "" ? ["0"] : params.split(";")
            for (var i = 0; i < p.length; i++) {
                var sub = p[i].indexOf(":") >= 0 ? p[i].split(":").filter(function(x) { return x !== "" }) : null
                var c = parseInt(sub ? sub[0] : p[i]) || 0
                if (c === 38 || c === 48) {
                    var args = sub ? sub.slice(1) : p.slice(i + 1), color = ""
                    if (args[0] === "5") { color = indexed(parseInt(args[1]) || 0); if (!sub) i += 2 }
                    else if (args[0] === "2") { color = "#" + hex(parseInt(args[1]) || 0) + hex(parseInt(args[2]) || 0) + hex(parseInt(args[3]) || 0); if (!sub) i += 4 }
                    if (c === 38) st.fg = color; else st.bg = color
                }
                else if (c === 0) st = {fg: "", bg: "", bold: false, dim: false, italic: false, underline: false, reverse: false}
                else if (c === 1) st.bold = true
                else if (c === 2) st.dim = true
                else if (c === 3) st.italic = true
                else if (c === 4) st.underline = true
                else if (c === 7) st.reverse = true
                else if (c === 22) { st.bold = false; st.dim = false }
                else if (c === 23) st.italic = false
                else if (c === 24) st.underline = false
                else if (c === 27) st.reverse = false
                else if (c >= 30 && c <= 37) st.fg = indexed(c - 30)
                else if (c === 39) st.fg = ""
                else if (c >= 40 && c <= 47) st.bg = indexed(c - 40)
                else if (c === 49) st.bg = ""
                else if (c >= 90 && c <= 97) st.fg = indexed(c - 82)
                else if (c >= 100 && c <= 107) st.bg = indexed(c - 92)
            }
        }
        function span(s) {
            if (!s) return ""
            var fg = st.fg || (st.dim ? palette[8] || "" : ""), bg = st.bg
            if (st.reverse) { var t = fg || String(theme.foreground); fg = bg || String(theme.background); bg = t }
            var css = (fg ? "color:" + fg + ";" : "") + (bg ? "background-color:" + bg + ";" : "") + (st.bold ? "font-weight:bold;" : "") + (st.italic ? "font-style:italic;" : "") + (st.underline ? "text-decoration:underline;" : "")
            return css ? '<span style="' + css + '">' + escape(s) + "</span>" : escape(s)
        }
        text = text.replace(/\x1b[()][0-9A-Za-z]/g, "").replace(/\x1b\][^\x07\x1b]*(\x07|\x1b\\)/g, "").replace(/\x1b\[[0-9;?]*[A-Za-ln-z]/g, "")
        var out = "", re = /\x1b\[([0-9;:]*)m/g, last = 0, m
        while ((m = re.exec(text)) !== null) { out += span(text.slice(last, m.index)); apply(m[1]); last = re.lastIndex }
        return "<pre>" + out + span(text.slice(last)).replace(/\x1b/g, "") + "</pre>"
    }
    Process {
        id: previewer
        property string key: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (previewer.key !== store.previewKey) return
                store.previewError = ""
                if (text === store.previewRaw) { store.unchangedPreviews++; return }
                store.previewRaw = text
                store.unchangedPreviews = 0
                var nl = text.indexOf("\n"), size = text.slice(0, nl).split(" ")
                store.previewCols = parseInt(size[0]) || 80; store.previewRows = parseInt(size[1]) || 24
                var html = store.ansiHtml(text.slice(nl + 1).replace(/\n+$/, ""))
                if (html !== store.previewHtml) store.previewHtml = html
                store.previewError = ""
            }
        }
        onExited: function(code, status) {
            if (code !== 0 && key === store.previewKey) store.previewError = "Preview unavailable"
            if (key !== store.previewKey) previewDelay.restart()
        }
    }
    signal opened()
    // Shared yerbad (resident Rust daemon) answers in ~11 ms; the Python bridge is the
    // fallback when the binary is missing or the daemon died.
    property QtObject yerbad: null
    property bool daemonBusy: false
    function refresh() {
        if (daemonBusy) return
        var asked = yerbad && yerbad.request("tmux.list", function(err, result) {
            store.daemonBusy = false
            store.error = err
            if (!err) store.applyListing(result)
        })
        if (asked) daemonBusy = true
        else if (!reader.running) { error = ""; reader.running = true }
    }
    function applyListing(data) {
        var rows = Array.isArray(data) ? store.withStatus(data) : []
        var snapshot = JSON.stringify(rows)
        if (snapshot !== store.entriesSnapshot) { store.entriesSnapshot = snapshot; store.entries = rows }
    }
    // noAnim: the dock already morphed into the scratchpad's rect, so skip Hyprland's slide.
    function open(item, noAnim) {
        if (opener.running) return
        error = ""
        opener.command = ["python3", Quickshell.shellPath("tmux_bridge.py"), "open", item.tmuxSession, item.tmuxWindow].concat(noAnim ? ["--no-anim"] : [])
        opener.running = true
    }
    Process {
        id: reader
        command: ["python3", Quickshell.shellPath("tmux_bridge.py"), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    store.applyListing(data)
                    store.error = data.error || ""
                }
                catch (e) { store.error = "Could not list tmux" }
            }
        }
        onExited: function(code, status) { if (code !== 0 && !store.error) store.error = "tmux query failed" }
    }
    Process {
        id: opener
        property bool ok: false
        onStarted: ok = false
        stdout: StdioCollector {
            onStreamFinished: {
                try { var data = JSON.parse(text); opener.ok = data.ok === true; store.error = data.error || "" }
                catch (e) { store.error = "Could not open tmux window" }
            }
        }
        onExited: function(code, status) {
            if (code === 0 && ok) store.opened()
            else { if (!store.error) store.error = "Failed to resume tmux"; }
        }
    }
}
