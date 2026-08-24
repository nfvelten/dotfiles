import QtQuick
import Quickshell
import Quickshell.Io

import "Vault.js" as Vault

// Shared state for the bar popup and the lazy full panel. Both show the same
// note list, so the listing runs once here rather than once per surface.
Item {
  id: root

  visible: false
  width: 0
  height: 0

  property var shell: null
  property var manifest: null
  property var pluginRegistry: null

  readonly property string home: Quickshell.env("HOME") || ""
  property string vaultPath: ""
  property int recentCount: 40
  property string captureHeading: "Quick Notes"
  readonly property string resolvedVault: vaultPath !== "" ? vaultPath : home + "/amphora"

  // Every note in the vault, used to resolve wikilinks by title. Cheap to
  // hold: the listing already walked the whole tree.
  property var index: []
  property var recent: []
  property var notes: []
  property var recentMtimes: ({})
  property string query: ""
  property bool searching: false
  property string status: ""

  signal noteWritten(string path)

  function applySettings(s) {
    if (!s) return
    if (typeof s.vaultPath === "string" && s.vaultPath !== "") vaultPath = s.vaultPath
    var count = Number(s.recentCount)
    if (isFinite(count) && count > 0) recentCount = Math.round(count)
    if (typeof s.captureHeading === "string" && s.captureHeading !== "")
      captureHeading = s.captureHeading
  }

  // ---------------------------------------------------------------- listing

  function refresh() {
    if (!listProcess.running) listProcess.running = true
  }

  function setQuery(text) {
    query = String(text || "")
    searchDebounce.restart()
  }

  function runQuery() {
    if (query.trim() === "") {
      notes = recent
      return
    }
    if (searchProcess.running) return
    searching = true
    searchProcess.running = true
  }

  Timer {
    id: searchDebounce
    interval: 180
    onTriggered: root.runQuery()
  }

  Process {
    id: listProcess
    running: false
    command: ["find", root.resolvedVault, "-type", "f", "-name", "*.md",
      "-not", "-path", "*/.*", "-printf", "%T@\t%p\n"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var all = Vault.parseListing(text, root.resolvedVault, 0)
        var parsed = all.slice(0, root.recentCount)
        root.index = all
        root.recent = parsed
        root.recentMtimes = Vault.mtimeMap(all)
        if (root.query.trim() === "") root.notes = parsed
      }
    }
  }

  Process {
    id: searchProcess
    running: false
    command: ["rg", "--files-with-matches", "--smart-case", "--glob", "*.md",
      "--", root.query, root.resolvedVault]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.searching = false
        root.notes = Vault.parseSearch(text, root.resolvedVault, root.recentMtimes)
      }
    }
    // rg exits 1 when nothing matched, which is an empty result, not a fault.
    onExited: root.searching = false
  }

  // ------------------------------------------------------- daily + capture

  function resolveNote(name) {
    return Vault.resolveNote(name, index)
  }

  function dailyPath() {
    return resolvedVault + "/" + Vault.dailyNotePath(new Date())
  }

  property string pendingCapture: ""

  function capture(entry) {
    var body = String(entry || "").trim()
    if (body === "") return false
    pendingCapture = body
    captureFile.path = dailyPath()
    captureFile.reload()
    return true
  }

  FileView {
    id: captureFile
    watchChanges: false
    printErrors: false

    onLoaded: root.writeCapture(text())
    onLoadFailed: root.writeCapture("")
  }

  function writeCapture(existing) {
    if (pendingCapture === "") return
    captureFile.setText(
      Vault.appendUnderHeading(existing, captureHeading, pendingCapture))
    pendingCapture = ""
    status = "Capturado na daily note"
    statusTimer.restart()
    noteWritten(captureFile.path)
    refreshDebounce.restart()
  }

  Timer {
    id: statusTimer
    interval: 2000
    onTriggered: root.status = ""
  }

  Timer {
    id: refreshDebounce
    interval: 300
    onTriggered: root.refresh()
  }

  Component.onCompleted: refresh()
}
