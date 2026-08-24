import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

import "Vault.js" as Vault

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  property string vaultPath: ""
  property int recentCount: 40
  property string captureHeading: "Quick Notes"

  property var notes: []
  property var recentMtimes: ({})
  property string searchText: ""
  property bool searching: false

  property string currentPath: ""
  property string currentTitle: ""
  property string draft: ""
  property bool editing: false
  property bool dirty: false
  property string status: ""

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string resolvedVault: vaultPath !== "" ? vaultPath : home + "/amphora"

  // ------------------------------------------------------------- lifecycle

  function open(payloadJson) {
    var payload = ({})
    try { if (payloadJson) payload = JSON.parse(payloadJson) } catch (e) {}
    applySettings(payload)
    opened = true
    refresh()
    if (payload.capture === true) Qt.callLater(function() { captureField.forceActiveFocus() })
    else Qt.callLater(function() { searchField.forceActiveFocus() })
    if (payload.today === true) Qt.callLater(function() { root.openDailyNote() })
  }

  function close() {
    // A close from the host must not drop an unsaved edit on the floor.
    if (dirty) saveDraft()
    opened = false
  }

  function requestClose() {
    if (shell && typeof shell.hide === "function") shell.hide("nfvelten.vault")
    else close()
  }

  function applySettings(payload) {
    var s = payload && payload.settings ? payload.settings : {}
    if (typeof s.vaultPath === "string" && s.vaultPath !== "") vaultPath = s.vaultPath
    var count = Number(s.recentCount)
    if (isFinite(count) && count > 0) recentCount = Math.round(count)
    if (typeof s.captureHeading === "string" && s.captureHeading !== "")
      captureHeading = s.captureHeading
  }

  // ---------------------------------------------------------------- listing

  function refresh() {
    if (searchText.trim() !== "") runSearch()
    else listProcess.running = true
  }

  Process {
    id: listProcess
    running: false
    command: ["find", root.resolvedVault, "-type", "f", "-name", "*.md",
      "-not", "-path", "*/.*", "-printf", "%T@\t%p\n"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Vault.parseListing(text, root.resolvedVault, root.recentCount)
        root.notes = parsed
        root.recentMtimes = Vault.mtimeMap(parsed)
        if (root.currentPath === "" && parsed.length > 0) root.selectNote(parsed[0])
      }
    }
  }

  Process {
    id: searchProcess
    running: false
    command: ["rg", "--files-with-matches", "--smart-case", "--glob", "*.md",
      "--", root.searchText, root.resolvedVault]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.searching = false
        root.notes = Vault.parseSearch(text, root.resolvedVault, root.recentMtimes)
      }
    }
    // rg exits 1 on "no matches", which is not an error worth surfacing.
    onExited: root.searching = false
  }

  function runSearch() {
    if (searchProcess.running) return
    searching = true
    searchProcess.running = true
  }

  Timer {
    id: searchDebounce
    interval: 180
    onTriggered: root.refresh()
  }

  // ------------------------------------------------------------------ notes

  function selectNote(note) {
    if (!note || !note.path) return
    if (dirty) saveDraft()
    currentPath = note.path
    currentTitle = note.title
    editing = false
    noteFile.path = note.path
  }

  FileView {
    id: noteFile
    watchChanges: true
    printErrors: false

    onLoaded: {
      // A change on disk while editing would silently discard the draft, so
      // an in-progress edit keeps what the user typed.
      if (root.editing && root.dirty) return
      root.draft = text()
      root.dirty = false
    }
    onLoadFailed: {
      root.draft = ""
      root.status = "Não consegui ler a nota."
    }
  }

  function saveDraft() {
    if (!dirty || currentPath === "") return
    noteFile.setText(draft)
    dirty = false
    status = "Salvo"
    statusTimer.restart()
  }

  Timer {
    id: statusTimer
    interval: 2000
    onTriggered: root.status = ""
  }

  // ------------------------------------------------------- daily + capture

  function dailyPath() {
    return resolvedVault + "/" + Vault.dailyNotePath(new Date())
  }

  function openDailyNote() {
    var path = dailyPath()
    selectNote({ path: path, title: Vault.noteTitle(path) })
  }

  function capture(entry) {
    var body = entry.trim()
    if (body === "") return
    captureFile.path = dailyPath()
    pendingCapture = body
    // The write happens in onLoaded/onLoadFailed: the section can only be
    // found once the note is in hand.
    captureFile.reload()
  }

  property string pendingCapture: ""

  FileView {
    id: captureFile
    watchChanges: false
    printErrors: false

    onLoaded: root.writeCapture(text())
    onLoadFailed: root.writeCapture("")
  }

  function writeCapture(existing) {
    if (pendingCapture === "") return
    var next = Vault.appendUnderHeading(existing, captureHeading, pendingCapture)
    captureFile.setText(next)
    pendingCapture = ""
    status = "Capturado na daily note"
    statusTimer.restart()
    captureField.text = ""
    refreshDebounce.restart()
    // Editing the note that is open on the right: pull the new text in.
    if (currentPath === captureFile.path) noteFile.reload()
  }

  Timer {
    id: refreshDebounce
    interval: 300
    onTriggered: root.refresh()
  }

  // ------------------------------------------------------------------- IPC

  IpcHandler {
    target: "nfvelten.vault"

    function toggle(): void {
      if (root.shell && typeof root.shell.toggle === "function")
        root.shell.toggle("nfvelten.vault", "{}")
    }
    function today(): void {
      if (root.shell && typeof root.shell.summon === "function")
        root.shell.summon("nfvelten.vault", JSON.stringify({ today: true }))
    }
    function capture(text: string): string {
      if (String(text || "").trim() === "") return "empty"
      root.capture(String(text))
      return "ok"
    }
  }

  // ------------------------------------------------------------------- view

  FloatingWindow {
    id: window
    visible: root.opened
    title: "Vault"
    color: Color.background
    implicitWidth: 1020
    implicitHeight: 700
    minimumSize: Qt.size(720, 480)

    onVisibleChanged: if (!visible && root.opened) root.requestClose()

    FocusScope {
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
          root.saveDraft()
          event.accepted = true
        } else if (event.key === Qt.Key_E && (event.modifiers & Qt.ControlModifier)) {
          root.editing = !root.editing
          event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
          if (root.editing) { root.saveDraft(); root.editing = false }
          else root.requestClose()
          event.accepted = true
        }
      }

      Column {
        anchors.fill: parent
        anchors.margins: Style.space(14)
        spacing: Style.space(10)

        // ---- header: search, today, capture
        Row {
          id: header
          width: parent.width
          spacing: Style.space(8)

          TextField {
            id: searchField
            width: parent.width - todayButton.width - captureField.width
              - captureButton.width - parent.spacing * 3
            placeholderText: "Buscar no vault…"
            onTextChanged: {
              root.searchText = text
              searchDebounce.restart()
            }
          }

          Button {
            id: todayButton
            text: "Hoje"
            onClicked: root.openDailyNote()
          }

          TextField {
            id: captureField
            width: Style.space(260)
            placeholderText: "Captura rápida…"
            onAccepted: root.capture(text)
          }

          Button {
            id: captureButton
            text: "Capturar"
            onClicked: root.capture(captureField.text)
          }
        }

        // ---- body: note list + reader/editor
        Row {
          width: parent.width
          height: parent.height - header.height - footer.height - parent.spacing * 2
          spacing: Style.space(12)

          BorderSurface {
            width: Style.space(280)
            height: parent.height

            ListView {
              id: noteList
              anchors.fill: parent
              anchors.margins: Style.space(4)
              clip: true
              model: root.notes
              currentIndex: -1

              delegate: Rectangle {
                required property var modelData
                width: noteList.width
                height: Style.space(46)
                color: modelData.path === root.currentPath
                  ? Style.selectedFill
                  : (noteMouse.containsMouse ? Style.hoverFill : "transparent")

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  anchors.right: timeLabel.left
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(6)
                  spacing: Style.space(2)

                  Text {
                    width: parent.width
                    text: modelData.title
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: modelData.folder
                    visible: modelData.folder !== ""
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideLeft
                  }
                }

                Text {
                  id: timeLabel
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  text: Vault.relativeTime(modelData.mtime, Date.now() / 1000)
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: noteMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  onClicked: root.selectNote(modelData)
                  onDoubleClicked: {
                    root.selectNote(modelData)
                    root.editing = true
                  }
                }
              }
            }

            Text {
              anchors.centerIn: parent
              visible: root.notes.length === 0
              text: root.searching ? "Buscando…" : "Nenhuma nota"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }

          BorderSurface {
            width: parent.width - Style.space(280) - parent.spacing
            height: parent.height

            Column {
              anchors.fill: parent
              anchors.margins: Style.space(12)
              spacing: Style.space(8)

              Row {
                id: noteHeader
                width: parent.width
                spacing: Style.space(8)

                Text {
                  width: parent.width - modeButton.width - parent.spacing
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.currentTitle !== "" ? root.currentTitle : "Nenhuma nota aberta"
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title
                  elide: Text.ElideRight
                }

                Button {
                  id: modeButton
                  text: root.editing ? "Ler  Ctrl+E" : "Editar  Ctrl+E"
                  enabled: root.currentPath !== ""
                  onClicked: {
                    if (root.editing) root.saveDraft()
                    root.editing = !root.editing
                    if (root.editing) Qt.callLater(function() { editor.forceActiveFocus() })
                  }
                }
              }

              PanelSeparator { width: parent.width }

              ScrollView {
                width: parent.width
                height: parent.height - noteHeader.height - parent.spacing * 3
                  - Style.space(1)
                clip: true

                // Reading renders the markdown; editing shows it raw, so the
                // syntax being typed is the syntax on screen.
                Text {
                  visible: !root.editing
                  width: parent.width
                  text: root.draft
                  textFormat: Text.MarkdownText
                  wrapMode: Text.Wrap
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  onLinkActivated: function(link) { Qt.openUrlExternally(link) }
                }

                TextArea {
                  id: editor
                  visible: root.editing
                  width: parent.width
                  text: root.draft
                  wrapMode: TextEdit.Wrap
                  color: Color.foreground
                  selectionColor: Style.selectionFill
                  selectedTextColor: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  background: null
                  onTextChanged: {
                    if (!root.editing || text === root.draft) return
                    root.draft = text
                    root.dirty = true
                    autosave.restart()
                  }
                }
              }
            }
          }
        }

        // ---- footer: path + save state
        Row {
          id: footer
          width: parent.width
          spacing: Style.space(8)

          Text {
            width: parent.width - stateLabel.width - parent.spacing
            text: root.currentPath
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideLeft
          }

          Text {
            id: stateLabel
            text: root.status !== "" ? root.status : (root.dirty ? "Não salvo" : "")
            color: root.dirty ? Color.urgent : Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  // Autosave keeps the vault's own minute-by-minute git commits meaningful
  // without needing Ctrl+S after every keystroke.
  Timer {
    id: autosave
    interval: 1500
    onTriggered: root.saveDraft()
  }
}
