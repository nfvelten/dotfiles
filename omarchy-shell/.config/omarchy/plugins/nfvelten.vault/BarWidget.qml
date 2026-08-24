import QtQuick
import qs.Commons
import qs.Ui

import "Vault.js" as Vault

BarWidget {
  id: root
  moduleName: "nfvelten.vault"

  readonly property var vault: bar && bar.shell
    ? bar.shell.serviceFor("nfvelten.vault") : null
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color secondary: Util.alpha(foreground, 0.55)

  property bool popupOpen: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onVaultChanged: if (vault) vault.applySettings(root.settings)

  function openPopup() {
    if (vault) { vault.setQuery(""); vault.refresh() }
    popupOpen = true
    Qt.callLater(function() { searchField.forceActiveFocus() })
  }

  function closePopup() {
    popupOpen = false
  }

  function toggle() {
    popupOpen ? closePopup() : openPopup()
  }

  // The popup is the everyday surface; the full window is the escape hatch,
  // reached from here or from SUPER+SHIFT+V.
  function openFull(payload) {
    closePopup()
    if (!bar || !bar.shell) return
    var next = payload || ({})
    next.settings = root.settings
    bar.shell.summon("nfvelten.vault", JSON.stringify(next))
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱓵"
    tooltipText: "Vault"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.openFull({ today: true })
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    focusTarget: searchField
    contentWidth: fittedContentWidth(Style.space(360))
    contentHeight: fittedContentHeight(contentColumn.implicitHeight)

    Column {
      id: contentColumn
      anchors.fill: parent
      spacing: Style.space(8)

      TextField {
        id: searchField
        width: parent.width
        foreground: root.foreground
        placeholderText: "Buscar no vault…"
        onTextChanged: if (root.vault) root.vault.setQuery(text)
        Keys.onDownPressed: noteList.forceActiveFocus()
        Keys.onEscapePressed: root.closePopup()
        onAccepted: {
          var list = root.vault ? root.vault.notes : []
          if (list.length > 0) root.openFull({ path: list[0].path })
        }
      }

      ListView {
        id: noteList
        width: parent.width
        height: Math.min(Style.space(300), Math.max(Style.space(34), contentHeight))
        clip: true
        model: root.vault ? root.vault.notes.slice(0, 12) : []
        currentIndex: 0
        keyNavigationEnabled: true

        delegate: NoteRow {
          required property var modelData
          width: noteList.width
          compact: true
          foreground: root.foreground
          title: modelData.title
          folder: modelData.folder
          age: Vault.relativeTime(modelData.mtime, Date.now() / 1000)
          selected: ListView.isCurrentItem
          onActivated: root.openFull({ path: modelData.path })
        }

        Keys.onReturnPressed: {
          var item = model[currentIndex]
          if (item) root.openFull({ path: item.path })
        }
        Keys.onEscapePressed: root.closePopup()
      }

      Text {
        width: parent.width
        visible: !root.vault || root.vault.notes.length === 0
        text: root.vault && root.vault.searching ? "Buscando…" : "Nenhuma nota"
        color: root.secondary
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        horizontalAlignment: Text.AlignHCenter
      }

      PanelSeparator { width: parent.width }

      Row {
        width: parent.width
        spacing: Style.space(6)

        Text {
          width: parent.width - fullButton.width - parent.spacing
          anchors.verticalCenter: parent.verticalCenter
          text: "Super+Shift+V"
          color: root.secondary
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        Button {
          id: fullButton
          text: "Abrir tudo"
          foreground: root.foreground
          onClicked: root.openFull({})
        }
      }
    }
  }
}
