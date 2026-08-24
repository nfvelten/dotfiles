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
  property var service: null
  property bool opened: false

  property string currentPath: ""
  property string currentTitle: ""
  property string draft: ""
  property bool editing: false
  property bool dirty: false
  property string status: ""

  // One hue, two weights. Anything secondary is the same foreground at lower
  // opacity — never a second colour.
  readonly property color foreground: Color.foreground
  readonly property color secondary: Util.alpha(foreground, 0.55)

  // Rendering markdown costs roughly the size of the note, and a Text item fed
  // a megabyte draws nothing at all rather than drawing slowly. The vault has
  // one note past this mark; everything else renders whole.
  readonly property int previewLimit: 200000
  readonly property bool oversized: draft.length > previewLimit

  readonly property var notes: service ? service.notes : []

  // ------------------------------------------------------------- lifecycle

  function open(payloadJson) {
    var payload = ({})
    try { if (payloadJson) payload = JSON.parse(payloadJson) } catch (e) {}
    if (service) {
      service.applySettings(payload.settings)
      service.refresh()
    }
    opened = true

    if (typeof payload.path === "string" && payload.path !== "")
      selectPath(payload.path)
    else if (payload.today === true) openDailyNote()
    else if (currentPath === "" && notes.length > 0) selectPath(notes[0].path)

    Qt.callLater(function() { searchField.forceActiveFocus() })
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

  onNotesChanged: {
    if (currentPath === "" && notes.length > 0) selectPath(notes[0].path)
  }

  // The editor takes the draft on entry rather than binding to it: the binding
  // would be broken by the first keystroke anyway, since typing writes back
  // into draft.
  onEditingChanged: if (editing) editor.text = draft

  // ------------------------------------------------------------------ notes

  function selectPath(path) {
    if (!path || path === currentPath) return
    if (dirty) saveDraft()
    currentPath = path
    currentTitle = Vault.noteTitle(path)
    editing = false
    noteFile.path = path
  }

  FileView {
    id: noteFile
    watchChanges: true
    printErrors: false

    onLoaded: {
      // A change on disk while editing would silently discard the draft, so an
      // in-progress edit keeps what the user typed.
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
    if (!dirty || currentPath === "" || oversized) return
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

  // Autosave keeps the vault's own minute-by-minute git commits meaningful
  // without needing Ctrl+S after every keystroke.
  Timer {
    id: autosave
    interval: 1500
    onTriggered: root.saveDraft()
  }

  function openDailyNote() {
    if (service) selectPath(service.dailyPath())
  }

  Connections {
    target: root.service
    ignoreUnknownSignals: true
    function onNoteWritten(path) {
      if (path === root.currentPath) noteFile.reload()
    }
  }

  // ------------------------------------------------------------------- IPC

  IpcHandler {
    target: "nfvelten.vault"

    function today(): void {
      if (root.shell && typeof root.shell.summon === "function")
        root.shell.summon("nfvelten.vault", JSON.stringify({ today: true }))
    }
    function capture(text: string): string {
      if (!root.service) return "unavailable"
      return root.service.capture(text) ? "ok" : "empty"
    }
  }

  // ------------------------------------------------------------------- view

  FloatingWindow {
    id: window
    visible: root.opened
    title: "Vault"
    color: Color.background
    implicitWidth: 1100
    implicitHeight: 650
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
          if (!root.oversized) root.editing = !root.editing
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
            foreground: root.foreground
            placeholderText: "Buscar no vault…"
            onTextChanged: if (root.service) root.service.setQuery(text)
          }

          Button {
            id: todayButton
            text: "Hoje"
            foreground: root.foreground
            onClicked: root.openDailyNote()
          }

          TextField {
            id: captureField
            width: Style.space(260)
            foreground: root.foreground
            placeholderText: "Captura rápida…"
            onAccepted: root.doCapture()
          }

          Button {
            id: captureButton
            text: "Capturar"
            foreground: root.foreground
            onClicked: root.doCapture()
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
            // Rectangle defaults to white; both surfaces take the kit's fill
            // and border so they sit on the theme instead of punching a hole.
            color: Style.normalFillFor(root.foreground, root.foreground)
            borderSpec: Border.controlSpec("normal", root.foreground, root.foreground)

            ListView {
              id: noteList
              anchors.fill: parent
              anchors.margins: Style.space(4)
              clip: true
              model: root.notes

              delegate: NoteRow {
                required property var modelData
                width: noteList.width
                foreground: root.foreground
                title: modelData.title
                folder: modelData.folder
                age: Vault.relativeTime(modelData.mtime, Date.now() / 1000)
                selected: modelData.path === root.currentPath
                onActivated: root.selectPath(modelData.path)
              }
            }

            Text {
              anchors.centerIn: parent
              visible: root.notes.length === 0
              text: root.service && root.service.searching ? "Buscando…" : "Nenhuma nota"
              color: root.secondary
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }

          BorderSurface {
            width: parent.width - Style.space(280) - parent.spacing
            height: parent.height
            color: Style.normalFillFor(root.foreground, root.foreground)
            borderSpec: Border.controlSpec("normal", root.foreground, root.foreground)

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
                  color: root.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title
                  elide: Text.ElideRight
                }

                Button {
                  id: modeButton
                  text: root.editing ? "Ler  Ctrl+E" : "Editar  Ctrl+E"
                  foreground: root.foreground
                  // Editing an oversized note would mean loading it whole into
                  // a TextArea and risking a save that writes back the recorte.
                  enabled: root.currentPath !== "" && !root.oversized
                  onClicked: {
                    if (root.editing) root.saveDraft()
                    root.editing = !root.editing
                    if (root.editing) Qt.callLater(function() { editor.forceActiveFocus() })
                  }
                }
              }

              PanelSeparator { width: parent.width }

              Text {
                id: oversizedNotice
                width: parent.width
                visible: root.oversized
                text: "Nota grande (" + Math.round(root.draft.length / 1024)
                  + " KB). Mostrando os primeiros "
                  + Math.round(root.previewLimit / 1024)
                  + " KB — edição desabilitada para não truncar o arquivo."
                wrapMode: Text.Wrap
                color: root.secondary
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }

              // One ScrollView per mode. A ScrollView adopts a single child
              // as its content item, so keeping the reader and the editor in
              // the same one left the editor unmanaged and scrolled adrift.
              Item {
                id: contentArea
                width: parent.width
                height: parent.height - noteHeader.height - Style.space(1)
                  - (root.oversized ? oversizedNotice.implicitHeight + parent.spacing : 0)
                  - parent.spacing * 3

                ScrollView {
                  anchors.fill: parent
                  visible: !root.editing
                  clip: true

                  Text {
                    width: contentArea.width
                    text: root.oversized ? root.draft.slice(0, root.previewLimit) : root.draft
                    textFormat: Text.MarkdownText
                    wrapMode: Text.Wrap
                    color: root.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    onLinkActivated: function(link) { Qt.openUrlExternally(link) }
                  }
                }

                ScrollView {
                  anchors.fill: parent
                  visible: root.editing
                  clip: true

                  // Raw markdown while editing, so the syntax being typed is
                  // the syntax on screen.
                  TextArea {
                    id: editor
                    wrapMode: TextEdit.Wrap
                    color: root.foreground
                    selectionColor: Util.alpha(root.foreground, 0.25)
                    selectedTextColor: root.foreground
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
        }

        // ---- footer: path + save state
        Row {
          id: footer
          width: parent.width
          spacing: Style.space(8)

          Text {
            width: parent.width - stateLabel.width - parent.spacing
            text: root.currentPath
            color: root.secondary
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideLeft
          }

          Text {
            id: stateLabel
            text: root.status !== "" ? root.status
              : (root.service && root.service.status !== "" ? root.service.status
                : (root.dirty ? "Não salvo" : ""))
            color: root.secondary
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  function doCapture() {
    if (!service || !service.capture(captureField.text)) return
    captureField.text = ""
  }
}
