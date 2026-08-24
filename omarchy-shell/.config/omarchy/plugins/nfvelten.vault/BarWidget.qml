import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "nfvelten.vault"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function openPanel(payload) {
    if (!bar || !bar.shell) return
    var next = payload || ({})
    next.settings = root.settings
    bar.shell.toggle("nfvelten.vault", JSON.stringify(next))
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱓵"
    tooltipText: "Vault"
    onPressed: function(buttonCode) {
      // Right click goes straight to today's daily note.
      if (buttonCode === Qt.RightButton) root.openPanel({ today: true })
      else root.openPanel({})
    }
  }
}
